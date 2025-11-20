require "uri"
require "base64"

module ScoutApmMcp
  # Helper module for API key management and URL parsing
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
      # Use provided API key if available
      return api_key if api_key && !api_key.empty?

      # Check environment variable (may have been set by opdotenv loaded early in server startup)
      api_key = ENV["API_KEY"] || ENV["SCOUT_APM_API_KEY"]
      return api_key if api_key && !api_key.empty?

      # Try direct 1Password CLI as fallback (opdotenv was already tried in server startup)
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
          # Silently fail
        end
      end

      raise "API_KEY not found. " \
            "Set API_KEY or SCOUT_APM_API_KEY environment variable, " \
            "or provide OP_ENV_ENTRY_PATH, or op_vault and op_item parameters for 1Password integration"
    end

    # Parse a ScoutAPM trace URL and extract app_id, endpoint_id, and trace_id
    #
    # @param url [String] Full ScoutAPM trace URL
    # @return [Hash] Hash containing :app_id, :endpoint_id, :trace_id, :query_params, and :decoded_endpoint
    def self.parse_scout_url(url)
      uri = URI.parse(url)
      path_parts = uri.path.split("/").reject(&:empty?)

      # Extract from URL: /apps/{app_id}/endpoints/{endpoint_id}/trace/{trace_id}
      app_index = path_parts.index("apps")
      endpoints_index = path_parts.index("endpoints")
      trace_index = path_parts.index("trace")

      result = {}

      if app_index && endpoints_index && trace_index
        result[:app_id] = path_parts[app_index + 1].to_i
        result[:endpoint_id] = path_parts[endpoints_index + 1]
        result[:trace_id] = path_parts[trace_index + 1].to_i
      else
        # Fallback: try to extract by position
        result[:app_id] = path_parts[1].to_i if path_parts[0] == "apps"
        result[:endpoint_id] = path_parts[3] if path_parts[2] == "endpoints"
        result[:trace_id] = path_parts[5].to_i if path_parts[4] == "trace"
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
      # Check if decoded result is valid UTF-8
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
  end
end
