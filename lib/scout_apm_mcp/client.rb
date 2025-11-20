require "uri"
require "net/http"
require "json"
require "base64"

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

    # @param api_key [String] ScoutAPM API key
    # @param api_base [String] API base URL (default: https://scoutapm.com/api/v0)
    def initialize(api_key:, api_base: API_BASE)
      @api_key = api_key
      @api_base = api_base
    end

    # List all applications accessible with the provided API key
    #
    # @return [Hash] API response containing applications list
    def list_apps
      uri = URI("#{@api_base}/apps")
      make_request(uri)
    end

    # Get application details for a specific application
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @return [Hash] API response containing application details
    def get_app(app_id)
      uri = URI("#{@api_base}/apps/#{app_id}")
      make_request(uri)
    end

    # List available metric types for an application
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @return [Hash] API response containing available metrics
    def list_metrics(app_id)
      uri = URI("#{@api_base}/apps/#{app_id}/metrics")
      make_request(uri)
    end

    # Get time-series data for a specific metric type
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param metric_type [String] Metric type (apdex, response_time, response_time_95th, errors, throughput, queue_time)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Hash] API response containing metric data
    def get_metric(app_id, metric_type, from: nil, to: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/metrics/#{metric_type}")
      uri.query = build_query_string(from: from, to: to)
      make_request(uri)
    end

    # List all endpoints for an application
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Hash] API response containing endpoints list
    def list_endpoints(app_id, from: nil, to: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints")
      uri.query = build_query_string(from: from, to: to)
      make_request(uri)
    end

    # Get endpoint details
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param endpoint_id [String] Endpoint ID (base64 URL-encoded)
    # @return [Hash] API response containing endpoint details
    def get_endpoint(app_id, endpoint_id)
      encoded_endpoint_id = URI.encode_www_form_component(endpoint_id)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints/#{encoded_endpoint_id}")
      make_request(uri)
    end

    # Get metric data for a specific endpoint
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param endpoint_id [String] Endpoint ID (base64 URL-encoded)
    # @param metric_type [String] Metric type (apdex, response_time, response_time_95th, errors, throughput, queue_time)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Hash] API response containing endpoint metrics
    def get_endpoint_metrics(app_id, endpoint_id, metric_type, from: nil, to: nil)
      encoded_endpoint_id = URI.encode_www_form_component(endpoint_id)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints/#{encoded_endpoint_id}/metrics/#{metric_type}")
      uri.query = build_query_string(from: from, to: to)
      make_request(uri)
    end

    # List traces for a specific endpoint (max 100, within 7 days)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param endpoint_id [String] Endpoint ID (base64 URL-encoded)
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @return [Hash] API response containing traces list
    def list_endpoint_traces(app_id, endpoint_id, from: nil, to: nil)
      encoded_endpoint_id = URI.encode_www_form_component(endpoint_id)
      uri = URI("#{@api_base}/apps/#{app_id}/endpoints/#{encoded_endpoint_id}/traces")
      uri.query = build_query_string(from: from, to: to)
      make_request(uri)
    end

    # Fetch detailed trace information
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param trace_id [Integer] Trace identifier
    # @return [Hash] API response containing trace details
    def fetch_trace(app_id, trace_id)
      uri = URI("#{@api_base}/apps/#{app_id}/traces/#{trace_id}")
      make_request(uri)
    end

    # List error groups for an application (max 100, within 30 days)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param from [String, nil] Start time in ISO 8601 format
    # @param to [String, nil] End time in ISO 8601 format
    # @param endpoint [String, nil] Base64 URL-encoded endpoint filter (optional)
    # @return [Hash] API response containing error groups list
    def list_error_groups(app_id, from: nil, to: nil, endpoint: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/error_groups")
      params = {}
      params["from"] = from if from
      params["to"] = to if to
      params["endpoint"] = endpoint if endpoint
      uri.query = URI.encode_www_form(params) unless params.empty?
      make_request(uri)
    end

    # Get details for a specific error group
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param error_id [Integer] Error group identifier
    # @return [Hash] API response containing error group details
    def get_error_group(app_id, error_id)
      uri = URI("#{@api_base}/apps/#{app_id}/error_groups/#{error_id}")
      make_request(uri)
    end

    # Get individual errors within an error group (max 100)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param error_id [Integer] Error group identifier
    # @return [Hash] API response containing errors list
    def get_error_group_errors(app_id, error_id)
      uri = URI("#{@api_base}/apps/#{app_id}/error_groups/#{error_id}/errors")
      make_request(uri)
    end

    # Get all insight types for an application (cached for 5 minutes)
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param limit [Integer, nil] Maximum number of items per insight type (default: 20)
    # @return [Hash] API response containing all insights
    def get_all_insights(app_id, limit: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/insights")
      uri.query = "limit=#{limit}" if limit
      make_request(uri)
    end

    # Get data for a specific insight type
    #
    # @param app_id [Integer] ScoutAPM application ID
    # @param insight_type [String] Insight type (n_plus_one, memory_bloat, slow_query)
    # @param limit [Integer, nil] Maximum number of items (default: 20)
    # @return [Hash] API response containing insights
    def get_insight_by_type(app_id, insight_type, limit: nil)
      uri = URI("#{@api_base}/apps/#{app_id}/insights/#{insight_type}")
      uri.query = "limit=#{limit}" if limit
      make_request(uri)
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
        raise "Authentication failed. Check your API key."
      else
        raise "API request failed: #{response.code} #{response.message}"
      end
    end

    private

    # Build HTTP client
    #
    # @param uri [URI] URI object for the request
    # @return [Net::HTTP] Configured HTTP client
    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 10
      http.open_timeout = 10
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
      request["Accept"] = "application/json"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPUnauthorized
        raise "Authentication failed. Check your API key. Response: #{response.body}"
      when Net::HTTPNotFound
        raise "Resource not found. Response: #{response.body}"
      else
        raise "API request failed: #{response.code} #{response.message}\n#{response.body}"
      end
    end
  end
end
