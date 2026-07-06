require "uri"
require "net/http"
require "openssl"
require "json"
require "base64"
require "time"

require_relative "errors"
require_relative "version"
require_relative "client/query_params"
require_relative "client/validation"
require_relative "client/http_transport"
require_relative "client/api"

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

    VALID_METRICS = %w[apdex response_time response_time_95th errors throughput queue_time].freeze
    VALID_INSIGHTS = %w[n_plus_one memory_bloat slow_query].freeze
    VALID_JOB_METRICS = %w[throughput execution_time latency errors allocations].freeze
    VALID_ENDPOINT_SORT_BY = %w[time_consumed response_time throughput error_rate].freeze
    VALID_ANOMALY_STATES = %w[open closed all].freeze

    MAX_REQUEST_ATTEMPTS = 3
    RETRY_BASE_DELAY_SECONDS = 0.5
    RETRYABLE_HTTP_STATUS_CODES = (500..599)

    include QueryParams
    include Validation
    include HttpTransport
    include Api::Apps
    include Api::Metrics
    include Api::Endpoints
    include Api::Jobs
    include Api::Traces
    include Api::ErrorGroups
    include Api::AnomalyEvents
    include Api::Insights
    include Api::OpenApi

    # @param api_key [String] ScoutAPM API key
    # @param api_base [String] API base URL (default: https://scoutapm.com/api/v0)
    # @raise [ArgumentError] if api_key is nil or empty
    def initialize(api_key:, api_base: API_BASE)
      if api_key.nil? || api_key.to_s.strip.empty?
        raise ArgumentError, "API key is required and cannot be nil or empty"
      end
      @api_key = api_key.to_s
      @api_base = api_base
      @user_agent = "scout-apm-mcp-rb/#{VERSION}"
    end
  end
end
