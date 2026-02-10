require "uri"
require "base64"
require "time"

module ScoutApmMcp
  # Helper module for API key management, URL parsing, and time utilities
  module Helpers
    # Get API key from environment or 1Password
    #
    # @param api_key [String, nil] Optional API key to use directly
    # @param op_vault [String, nil] 1Password vault name (optional)
    # @param op_item [String, nil] 1Password item name (optional)
    # @param op_field [String] 1Password field name (default: "API_KEY")
    # @return [String] API key
    # @raise [RuntimeError] if API key cannot be found
    def self.get_api_key(api_key: nil, op_vault: nil, op_item: nil, op_field: "API_KEY")
      return api_key if api_key && !api_key.empty?

      api_key = ENV["API_KEY"] || ENV["SCOUT_APM_API_KEY"]
      return api_key if api_key && !api_key.empty?
      op_env_entry_path = ENV["OP_ENV_ENTRY_PATH"]
      if op_env_entry_path && !op_env_entry_path.empty?
        begin
          # Extract vault and item from OP_ENV_ENTRY_PATH (format: op://Vault/Item)
          if op_env_entry_path =~ %r{op://([^/]+)/(.+)}
            vault = Regexp.last_match(1)
            item = Regexp.last_match(2)
            api_key = `op read "op://#{vault}/#{item}/#{op_field}" 2>/dev/null`.strip
            return api_key if api_key && !api_key.empty?
          end
        rescue
          # Silently fail and try other methods
        end
      end

      # Try to load from 1Password via opdotenv (if vault and item are provided)
      if op_vault && op_item
        begin
          require "opdotenv"
          Opdotenv::Loader.load("op://#{op_vault}/#{op_item}")
          api_key = ENV["API_KEY"] || ENV["SCOUT_APM_API_KEY"]
          return api_key if api_key && !api_key.empty?
        rescue LoadError
          # opdotenv not available, try direct op CLI
        rescue
          # Silently fail and try other methods
        end

        # Try direct 1Password CLI
        begin
          api_key = `op read "op://#{op_vault}/#{op_item}/#{op_field}" 2>/dev/null`.strip
          return api_key if api_key && !api_key.empty?
        rescue
        end
      end

      raise "API_KEY not found. " \
            "Set API_KEY or SCOUT_APM_API_KEY environment variable, " \
            "or provide OP_ENV_ENTRY_PATH, or op_vault and op_item parameters for 1Password integration"
    end

    # Parse a ScoutAPM URL and extract resource information
    #
    # @param url [String] Full ScoutAPM URL
    # @return [Hash] Hash containing resource type and extracted IDs
    #   Possible keys: :url_type, :app_id, :endpoint_id, :trace_id, :error_id, :insight_type,
    #   :query_params, :decoded_endpoint
    def self.parse_scout_url(url)
      uri = URI.parse(url)
      path_parts = uri.path.split("/").reject(&:empty?)

      result = {}
      app_index = path_parts.index("apps")

      return result unless app_index

      result[:app_id] = path_parts[app_index + 1].to_i

      # Detect URL type and extract IDs
      # Pattern: /apps/{app_id}/endpoints/{endpoint_id}/trace/{trace_id}
      if path_parts.include?("trace")
        result[:url_type] = :trace
        endpoints_index = path_parts.index("endpoints")
        trace_index = path_parts.index("trace")
        if endpoints_index && trace_index
          result[:endpoint_id] = path_parts[endpoints_index + 1]
          result[:trace_id] = path_parts[trace_index + 1].to_i
        end
      # Pattern: /apps/{app_id}/endpoints/{endpoint_id}
      elsif path_parts.include?("endpoints")
        result[:url_type] = :endpoint
        endpoints_index = path_parts.index("endpoints")
        result[:endpoint_id] = path_parts[endpoints_index + 1] if endpoints_index
      # Pattern: /apps/{app_id}/error_groups/{error_id}
      elsif path_parts.include?("error_groups")
        result[:url_type] = :error_group
        error_groups_index = path_parts.index("error_groups")
        result[:error_id] = path_parts[error_groups_index + 1].to_i if error_groups_index
      # Pattern: /apps/{app_id}/insights or /apps/{app_id}/insights/{insight_type}
      elsif path_parts.include?("insights")
        result[:url_type] = :insight
        insights_index = path_parts.index("insights")
        if insights_index && path_parts.length > insights_index + 1
          result[:insight_type] = path_parts[insights_index + 1]
        end
      # Pattern: /apps/{app_id}
      elsif path_parts.length == 2 && path_parts[0] == "apps"
        result[:url_type] = :app
      else
        result[:url_type] = :unknown
      end

      # Parse query parameters
      if uri.query
        query_params = URI.decode_www_form(uri.query).to_h
        result[:query_params] = query_params
      end

      # Decode endpoint ID for readability
      if result[:endpoint_id]
        result[:decoded_endpoint] = decode_endpoint_id(result[:endpoint_id])
      end

      result
    end

    # Decode endpoint ID from base64
    #
    # @param endpoint_id [String] Base64-encoded endpoint ID
    # @return [String] Decoded endpoint ID
    def self.decode_endpoint_id(endpoint_id)
      decoded = Base64.urlsafe_decode64(endpoint_id)
      if decoded.force_encoding(Encoding::UTF_8).valid_encoding?
        decoded.force_encoding(Encoding::UTF_8)
      else
        # Try standard base64
        decoded = Base64.decode64(endpoint_id)
        if decoded.force_encoding(Encoding::UTF_8).valid_encoding?
          decoded.force_encoding(Encoding::UTF_8)
        else
          # Return original string with proper encoding
          endpoint_id.dup.force_encoding(Encoding::UTF_8)
        end
      end
    rescue
      # If decoding raises an exception, return original string
      endpoint_id.dup.force_encoding(Encoding::UTF_8)
    end

    # Get a unique identifier for an endpoint from an endpoint dictionary
    #
    # This is provided by the API implicitly in the 'link' field.
    #
    # @param endpoint [Hash] Endpoint dictionary from the API
    # @return [String] Endpoint ID extracted from the link field, or empty string if not found
    def self.get_endpoint_id(endpoint)
      link = endpoint["link"] || endpoint[:link] || ""
      return "" if link.empty?

      # Extract the endpoint ID from the link (last path segment)
      link.split("/").last || ""
    end

    # Format datetime to ISO 8601 string for API
    #
    # Relies on UTC timezone. Converts the time to UTC if it's not already.
    #
    # @param time [Time] Time object to format
    # @return [String] ISO 8601 formatted time string (e.g., "2025-01-01T00:00:00Z")
    def self.format_time(time)
      time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    # Parse ISO 8601 time string to Time object
    #
    # Handles both 'Z' suffix and timezone offsets.
    #
    # @param time_str [String] ISO 8601 time string (e.g., "2025-01-01T00:00:00Z")
    # @return [Time] Time object in UTC
    def self.parse_time(time_str)
      # Replace Z with +00:00 for Ruby's Time parser
      normalized = time_str.sub(/Z\z/i, "+00:00")
      Time.parse(normalized).utc
    end

    # Create a Duration object from ISO 8601 strings
    #
    # @param from_str [String] Start time in ISO 8601 format
    # @param to_str [String] End time in ISO 8601 format
    # @return [Hash] Hash with :start and :end Time objects
    def self.make_duration(from_str, to_str)
      {
        start: parse_time(from_str),
        end: parse_time(to_str)
      }
    end

    # Parse a time range string into seconds
    #
    # Supports formats like: "30min", "60min", "3hrs", "6hrs", "12hrs", "1day", "3days", "7days"
    # Case-insensitive, supports singular and plural forms
    #
    # @param range_str [String] Time range string (e.g., "30min", "1day", "7days")
    # @return [Integer] Duration in seconds
    # @raise [ArgumentError] If the range string format is invalid
    def self.parse_range(range_str)
      return nil if range_str.nil? || range_str.empty?

      # Normalize: lowercase, remove spaces, handle singular/plural
      normalized = range_str.downcase.strip.gsub(/\s+/, "")

      # Match pattern: number followed by unit
      match = normalized.match(/\A(\d+)(min|mins?|hr|hrs?|hour|hours|day|days)\z/)
      unless match
        valid_ranges = %w[30min 60min 3hrs 6hrs 12hrs 1day 3days 7days]
        raise ArgumentError, "Invalid range format: #{range_str}. Valid formats: #{valid_ranges.join(", ")}"
      end

      value = match[1].to_i
      unit = match[2]

      case unit
      when /^min/
        value * 60
      when /^hr/, /^hour/
        value * 60 * 60
      when /^day/
        value * 24 * 60 * 60
      else
        raise ArgumentError, "Unknown time unit: #{unit}"
      end
    end

    # Calculate from/to times based on a range string
    #
    # @param range [String, nil] Time range string (e.g., "30min", "1day", "3days")
    # @param to [String, nil] End time in ISO 8601 format (defaults to now if not provided)
    # @return [Hash] Hash with :from and :to as ISO 8601 strings
    def self.calculate_range(range:, to: nil)
      return {from: nil, to: to} if range.nil? || range.to_s.strip.empty?

      # Normalize: MCP clients may pass integer (e.g. 7) instead of "7days"
      range_str = range.to_s.strip
      range_str = "#{range_str}days" if range_str.match?(/\A\d+\z/)

      end_time = to ? parse_time(to) : Time.now.utc
      duration_seconds = parse_range(range_str)
      start_time = end_time - duration_seconds

      {
        from: format_time(start_time),
        to: format_time(end_time)
      }
    end
  end
end
