require "uri"
require "net/http"
require "openssl"
require "json"
require "base64"
require "time"

require_relative "errors"
require_relative "version"

module ScoutApmMcp
  # ScoutAPM API client for making authenticated requests to the ScoutAPM API
  #
  # @example
  #   api_key = ScoutApmMcp::Helpers.get_api_key
  #   client = ScoutApmMcp::Client.new(api_key: api_key)
  #   apps = client.list_apps
  #   trace = client.fetch_trace(123, 456)
  class Client
    API_BASE = "https://scoutapm.com/api/v0"

    # Valid metric types
    VALID_METRICS = %w[apdex response_time response_time_95th errors throughput queue_time].freeze

    # Valid insight types
    VALID_INSIGHTS = %w[n_plus_one memory_bloat slow_query].freeze

    # @param api_key [String] ScoutAPM API key
    # @param api_base [String] API base URL (default: https://scoutapm.com/api/v0)
    def initialize(api_key:, api_base: API_BASE)
      @api_key = api_key
      @api_base = api_base
      @user_agent = "scout-apm-mcp-rb/#{VERSION}"
    end

    # List all applications accessible with the provided API key
    #
    # @param active_since [String, nil] ISO 8601 datetime string to filter apps active since that time (default: 30 days ago)
    # @return [Array<Hash>] Array of application hashes
    def list_apps(active_since: nil)
      uri = URI("#{@api_base}/apps")
      response = make_request(uri)
      apps = response.dig("results", "apps") || []

      # Filter by active_since if provided
      if active_since
        active_time = Helpers.parse_time(active_since)
        apps = apps.select do |app|
          reported_at = app["last_reported_at"]
          if reported_at && !reported_at.empty?
            Helpers.parse_time(reported_at) >= active_time
          else
            false
          end
        end
      end

      apps
    end

    # Get application details for a specific application
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @return [Hash] Application details hash
    def get_app(app_id)
      uri = URI("#{@api_base}/apps/#{app_id}")
      response = make_request(uri)
      response.dig("results", "app") || {}
    end

    # List available metric types for an application
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @return [Array<String>] Array of available metric type names
    def list_metrics(app_id)
      uri = URI("#{@api_base}/apps/#{app_id}/metrics")
      response = make_request(uri)
      response.dig("results", "availableMetrics") || []
    end

    # Get time-series data for a specific metric type
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param metric_type [String] Metric type (apdex, response_time, response_time_95th, errors, throughput, queue_time)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Hash] Hash containing metric series data
    def get_metric(app_id, metric_type, from: nil, to: nil)
      validate_metric_params(metric_type, from, to)
      uri = URI("#{@api_base}/apps/#{app_id}/metrics/#{metric_type}")
      uri.query = build_query_string(from: from, to: to)
      response = make_request(uri)
      response.dig("results", "series") || {}
    end

    # List all endpoints for an application
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Array<Hash>] Array of endpoint hashes
    def list_endpoints(app_id, from: nil, to: nil)
      validate_time_range(from, to) if from && to
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints")
      uri.query = build_query_string(from: from, to: to)
      response = make_request(uri)
      response["results"] || []
    end

    # Get endpoint details
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param endpoint_id [String] Endpoint ID (base64 URL-encoded)
    # @return [Hash] Endpoint details hash
    def get_endpoint(app_id, endpoint_id)
      encoded_endpoint_id = URI.encode_www_form_component(endpoint_id)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints/#{encoded_endpoint_id}")
      response = make_request(uri)
      response.dig("results", "endpoint") || response["results"] || {}
    end

    # Get metric data for a specific endpoint
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param endpoint_id [String] Endpoint ID (base64 URL-encoded)
    # @param metric_type [String] Metric type (apdex, response_time, response_time_95th, errors, throughput, queue_time)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Array] Array of metric data points for the specified metric type
    def get_endpoint_metrics(app_id, endpoint_id, metric_type, from: nil, to: nil)
      validate_metric_params(metric_type, from, to)
      encoded_endpoint_id = URI.encode_www_form_component(endpoint_id)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints/#{encoded_endpoint_id}/metrics/#{metric_type}")
      uri.query = build_query_string(from: from, to: to)
      response = make_request(uri)
      series = response.dig("results", "series") || {}
      series[metric_type] || []
    end

    # List traces for a specific endpoint (max 100, within 7 days)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param endpoint_id [String] Endpoint ID (base64 URL-encoded)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Array<Hash>] Array of trace hashes
    def list_endpoint_traces(app_id, endpoint_id, from: nil, to: nil)
      validate_time_range(from, to) if from && to
      if from && to
        # Validate that from_time is not older than 7 days
        from_time = Helpers.parse_time(from)
        seven_days_ago = Time.now.utc - (7 * 24 * 60 * 60)
        if from_time < seven_days_ago
          raise ArgumentError, "from_time cannot be older than 7 days"
        end
      end
      encoded_endpoint_id = URI.encode_www_form_component(endpoint_id)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints/#{encoded_endpoint_id}/traces")
      uri.query = build_query_string(from: from, to: to)
      response = make_request(uri)
      response.dig("results", "traces") || []
    end

    # Fetch detailed trace information
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param trace_id [Integer] Trace identifier
    # @return [Hash] Trace details hash
    def fetch_trace(app_id, trace_id)
      uri = URI("#{@api_base}/apps/#{app_id}/traces/#{trace_id}")
      response = make_request(uri)
      response.dig("results", "trace") || {}
    end

    # List error groups for an application (max 100, within 30 days)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @param endpoint [String, nil] Base64 URL-encoded endpoint filter (optional)
    # @return [Array<Hash>] Array of error group hashes
    def list_error_groups(app_id, from: nil, to: nil, endpoint: nil)
      validate_time_range(from, to) if from && to
      uri = URI("#{@api_base}/apps/#{app_id}/error_groups")
      params = {}
      params["from"] = from if from
      params["to"] = to if to
      params["endpoint"] = endpoint if endpoint
      uri.query = URI.encode_www_form(params) unless params.empty?
      response = make_request(uri)
      response.dig("results", "error_groups") || []
    end

    # Get details for a specific error group
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param error_id [Integer] Error group identifier
    # @return [Hash] Error group details hash
    def get_error_group(app_id, error_id)
      uri = URI("#{@api_base}/apps/#{app_id}/error_groups/#{error_id}")
      response = make_request(uri)
      response.dig("results", "error_group") || {}
    end

    # Get individual errors within an error group (max 100)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param error_id [Integer] Error group identifier
    # @return [Array<Hash>] Array of error hashes
    def get_error_group_errors(app_id, error_id)
      uri = URI("#{@api_base}/apps/#{app_id}/error_groups/#{error_id}/errors")
      response = make_request(uri)
      response.dig("results", "errors") || []
    end

    # Get all insight types for an application (cached for 5 minutes)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param limit [Integer, nil] Maximum number of items per insight type (default: 20)
    # @return [Hash] Hash containing all insight types
    def get_all_insights(app_id, limit: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/insights")
      uri.query = "limit=#{limit}" if limit
      response = make_request(uri)
      response["results"] || {}
    end

    # Get data for a specific insight type
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param insight_type [String] Insight type (n_plus_one, memory_bloat, slow_query)
    # @param limit [Integer, nil] Maximum number of items (default: 20)
    # @return [Hash] Hash containing insight data
    def get_insight_by_type(app_id, insight_type, limit: nil)
      unless VALID_INSIGHTS.include?(insight_type)
        raise ArgumentError, "Invalid insight_type. Must be one of: #{VALID_INSIGHTS.join(", ")}"
      end
      uri = URI("#{@api_base}/apps/#{app_id}/insights/#{insight_type}")
      uri.query = "limit=#{limit}" if limit
      response = make_request(uri)
      response["results"] || {}
    end

    # Get historical insights data with cursor-based pagination
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @param limit [Integer, nil] Maximum number of items per page (default: 10)
    # @param pagination_cursor [Integer, nil] Cursor for pagination (insight ID)
    # @param pagination_direction [String, nil] Pagination direction (forward, backward)
    # @param pagination_page [Integer, nil] Page number for pagination (default: 1)
    # @return [Hash] API response containing historical insights
    def get_insights_history(app_id, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/insights/history")
      params = {}
      params["from"] = from if from
      params["to"] = to if to
      params["limit"] = limit if limit
      params["pagination_cursor"] = pagination_cursor if pagination_cursor
      params["pagination_direction"] = pagination_direction if pagination_direction
      params["pagination_page"] = pagination_page if pagination_page
      uri.query = URI.encode_www_form(params) unless params.empty?
      make_request(uri)
    end

    # Get historical insights data filtered by insight type with cursor-based pagination
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param insight_type [String] Insight type (n_plus_one, memory_bloat, slow_query)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @param limit [Integer, nil] Maximum number of items per page (default: 10)
    # @param pagination_cursor [Integer, nil] Cursor for pagination (insight ID)
    # @param pagination_direction [String, nil] Pagination direction (forward, backward)
    # @param pagination_page [Integer, nil] Page number for pagination (default: 1)
    # @return [Hash] API response containing historical insights
    def get_insights_history_by_type(app_id, insight_type, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/insights/history/#{insight_type}")
      params = {}
      params["from"] = from if from
      params["to"] = to if to
      params["limit"] = limit if limit
      params["pagination_cursor"] = pagination_cursor if pagination_cursor
      params["pagination_direction"] = pagination_direction if pagination_direction
      params["pagination_page"] = pagination_page if pagination_page
      uri.query = URI.encode_www_form(params) unless params.empty?
      make_request(uri)
    end

    # Fetch the ScoutAPM OpenAPI schema
    #
    # @return [Hash] Hash containing :content, :content_type, and :status
    def fetch_openapi_schema
      uri = URI("https://scoutapm.com/api/v0/openapi.yaml")
      http = build_http_client(uri)

      request = Net::HTTP::Get.new(uri)
      request["X-SCOUT-API"] = @api_key
      request["User-Agent"] = @user_agent
      request["Accept"] = "application/x-yaml, application/yaml, text/yaml, */*"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        {
          content: response.body,
          content_type: response.content_type,
          status: response.code.to_i
        }
      when Net::HTTPUnauthorized
        raise AuthError, "Authentication failed. Check your API key."
      else
        raise APIError.new("API request failed: #{response.code} #{response.message}", status_code: response.code.to_i)
      end
    rescue OpenSSL::SSL::SSLError => e
      raise Error, "SSL verification failed: #{e.message}. This may be due to system certificate configuration issues."
    rescue Error
      raise
    rescue => e
      raise Error, "Request failed: #{e.class} - #{e.message}"
    end

    private

    # Build HTTP client
    #
    # @param uri [URI] URI object for the request
    # @return [Net::HTTP] Configured HTTP client
    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.open_timeout = 10

      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        # Set ca_file directly - this is the simplest and most reliable approach
        # Try SSL_CERT_FILE first, then default cert file
        ca_file = if ENV["SSL_CERT_FILE"] && File.file?(ENV["SSL_CERT_FILE"])
          ENV["SSL_CERT_FILE"]
        elsif File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
          OpenSSL::X509::DEFAULT_CERT_FILE
        end

        http.ca_file = ca_file if ca_file
      end

      http
    end

    def build_query_string(from: nil, to: nil)
      params = {}
      params["from"] = from if from
      params["to"] = to if to
      return nil if params.empty?
      URI.encode_www_form(params)
    end

    def make_request(uri)
      http = build_http_client(uri)

      request = Net::HTTP::Get.new(uri)
      request["X-SCOUT-API"] = @api_key
      request["User-Agent"] = @user_agent
      request["Accept"] = "application/json"

      response = http.request(request)
      response_data = handle_response_errors(response)

      # Check for API-level errors in response body
      if response_data.is_a?(Hash)
        header = response_data["header"]
        if header && header["status"]
          status_code = header["status"]["code"]
          if status_code && status_code >= 400
            error_msg = header["status"]["message"] || "Unknown API error"
            raise APIError.new(error_msg, status_code: status_code, response_data: response_data)
          end
        end
      end

      response_data
    rescue OpenSSL::SSL::SSLError => e
      raise Error, "SSL verification failed: #{e.message}. This may be due to system certificate configuration issues."
    rescue Error
      raise
    rescue => e
      raise Error, "Request failed: #{e.class} - #{e.message}"
    end

    # Handle common response errors and parse JSON
    #
    # @param response [Net::HTTPResponse] HTTP response object
    # @return [Hash, Array] Parsed JSON response
    # @raise [AuthError] When authentication fails
    # @raise [APIError] When the API returns an error response
    def handle_response_errors(response)
      # Try to parse JSON response
      begin
        data = JSON.parse(response.body)
      rescue JSON::ParserError
        raise APIError.new("Invalid JSON response: #{response.body}", status_code: response.code.to_i)
      end

      # Check for HTTP-level errors
      case response
      when Net::HTTPSuccess
        data
      when Net::HTTPUnauthorized
        raise AuthError, "Authentication failed - check your API key"
      when Net::HTTPNotFound
        raise APIError.new("Resource not found", status_code: 404, response_data: data)
      else
        error_msg = "API request failed"
        if data.is_a?(Hash) && data.dig("header", "status", "message")
          error_msg = data.dig("header", "status", "message")
        end
        raise APIError.new(error_msg, status_code: response.code.to_i, response_data: data)
      end
    end

    # Validate metric parameters
    #
    # @param metric_type [String] Metric type to validate
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @raise [ArgumentError] If validation fails
    def validate_metric_params(metric_type, from, to)
      unless VALID_METRICS.include?(metric_type)
        raise ArgumentError, "Invalid metric_type. Must be one of: #{VALID_METRICS.join(", ")}"
      end
      validate_time_range(from, to) if from && to
    end

    # Validate time ranges
    #
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @raise [ArgumentError] If validation fails
    def validate_time_range(from, to)
      return unless from && to

      from_time = Helpers.parse_time(from)
      to_time = Helpers.parse_time(to)

      if from_time >= to_time
        raise ArgumentError, "from_time must be before to_time"
      end

      # Validate time range (2 week maximum)
      max_duration = 14 * 24 * 60 * 60 # 14 days in seconds
      if (to_time - from_time) > max_duration
        raise ArgumentError, "Time range cannot exceed 2 weeks"
      end
    end
  end
end
