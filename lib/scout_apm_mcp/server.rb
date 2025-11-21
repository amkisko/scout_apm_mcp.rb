#!/usr/bin/env ruby
# frozen_string_literal: true

require "fast_mcp"
require "scout_apm_mcp"
require "logger"
require "stringio"
require "securerandom"

# Alias MCP to FastMcp for compatibility
FastMcp = MCP unless defined?(FastMcp)

# Monkey-patch fast-mcp to ensure error responses always have a valid id
# JSON-RPC 2.0 allows id: null for notifications, but MCP clients (Cursor/Inspector)
# use strict Zod validation that requires id to be a string or number
module MCP
  module Transports
    class StdioTransport
      if method_defined?(:send_error)
        alias_method :original_send_error, :send_error

        def send_error(code, message, id = nil)
          # Use placeholder id if nil to satisfy strict MCP client validation
          # JSON-RPC 2.0 allows null for notifications, but MCP clients require valid id
          id = "error_#{SecureRandom.hex(8)}" if id.nil?
          original_send_error(code, message, id)
        end
      end
    end
  end

  class Server
    if method_defined?(:send_error)
      alias_method :original_send_error, :send_error

      def send_error(code, message, id = nil)
        # Use placeholder id if nil to satisfy strict MCP client validation
        # JSON-RPC 2.0 allows null for notifications, but MCP clients require valid id
        id = "error_#{SecureRandom.hex(8)}" if id.nil?
        original_send_error(code, message, id)
      end
    end
  end
end

module ScoutApmMcp
  # MCP Server for ScoutAPM integration
  #
  # This server provides MCP tools for interacting with ScoutAPM API
  # Usage: bundle exec scout_apm_mcp
  class Server
    # Simple null logger that suppresses all output
    # Must implement the same interface as MCP::Logger
    class NullLogger
      attr_accessor :transport, :client_initialized

      def initialize
        @transport = nil
        @client_initialized = false
        @level = nil
      end

      attr_writer :level

      attr_reader :level

      def debug(*)
      end

      def info(*)
      end

      def warn(*)
      end

      def error(*)
      end

      def fatal(*)
      end

      def unknown(*)
      end

      def client_initialized?
        @client_initialized
      end

      def set_client_initialized(value = true)
        @client_initialized = value
      end

      def stdio_transport?
        @transport == :stdio
      end

      def rack_transport?
        @transport == :rack
      end
    end

    def self.start
      # Load 1Password credentials early if OP_ENV_ENTRY_PATH is set
      op_env_entry_path = ENV["OP_ENV_ENTRY_PATH"]
      if op_env_entry_path && !op_env_entry_path.empty?
        begin
          require "opdotenv"
          Opdotenv::Loader.load(op_env_entry_path)
        rescue LoadError
          # opdotenv not available, will fall back to op CLI in get_api_key
        rescue
          # Silently fail - will try other methods in get_api_key
        end
      end

      # Create server with null logger to prevent any output
      server = FastMcp::Server.new(
        name: "scout-apm",
        version: ScoutApmMcp::VERSION,
        logger: NullLogger.new
      )

      # Register all tools
      register_tools(server)

      # Start the server (blocks and speaks MCP over STDIN/STDOUT)
      server.start
    end

    def self.register_tools(server)
      server.register_tool(ListAppsTool)
      server.register_tool(GetAppTool)
      server.register_tool(ListMetricsTool)
      server.register_tool(GetMetricTool)
      server.register_tool(ListEndpointsTool)
      server.register_tool(FetchEndpointTool)
      server.register_tool(GetEndpointMetricsTool)
      server.register_tool(ListEndpointTracesTool)
      server.register_tool(FetchTraceTool)
      server.register_tool(ListErrorGroupsTool)
      server.register_tool(GetErrorGroupTool)
      server.register_tool(GetErrorGroupErrorsTool)
      server.register_tool(GetAllInsightsTool)
      server.register_tool(GetInsightByTypeTool)
      server.register_tool(GetInsightsHistoryTool)
      server.register_tool(GetInsightsHistoryByTypeTool)
      server.register_tool(ParseScoutURLTool)
      server.register_tool(FetchScoutURLTool)
      server.register_tool(FetchOpenAPISchemaTool)
    end

    # Base tool class with common error handling
    #
    # Exceptions raised in tool #call methods are automatically caught by fast-mcp
    # and converted to MCP error results with the request ID preserved.
    # fast-mcp uses send_error_result(message, id) which sends a result with
    # isError: true, not a JSON-RPC error response.
    class BaseTool < FastMcp::Tool
      protected

      def get_client
        api_key = Helpers.get_api_key
        Client.new(api_key: api_key)
      end
    end

    # Applications Tools
    class ListAppsTool < BaseTool
      description "List all applications accessible with the provided API key"

      arguments do
        # No arguments required
      end

      def call
        get_client.list_apps
      end
    end

    class GetAppTool < BaseTool
      description "Get application details for a specific application"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
      end

      def call(app_id:)
        get_client.get_app(app_id)
      end
    end

    # Metrics Tools
    class ListMetricsTool < BaseTool
      description "List available metric types for an application"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
      end

      def call(app_id:)
        get_client.list_metrics(app_id)
      end
    end

    class GetMetricTool < BaseTool
      description "Get time-series data for a specific metric type"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:metric_type).filled(:string).description("Metric type: apdex, response_time, response_time_95th, errors, throughput, queue_time")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
      end

      def call(app_id:, metric_type:, from: nil, to: nil)
        get_client.get_metric(app_id, metric_type, from: from, to: to)
      end
    end

    # Endpoints Tools
    class ListEndpointsTool < BaseTool
      description "List all endpoints for an application"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
      end

      def call(app_id:, from: nil, to: nil)
        get_client.list_endpoints(app_id, from: from, to: to)
      end
    end

    class FetchEndpointTool < BaseTool
      description "Fetch endpoint details from ScoutAPM API"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:endpoint_id).filled(:string).description("Endpoint ID (base64 URL-encoded)")
      end

      def call(app_id:, endpoint_id:)
        client = get_client
        {
          endpoint: client.get_endpoint(app_id, endpoint_id),
          decoded_endpoint: Helpers.decode_endpoint_id(endpoint_id)
        }
      end
    end

    class GetEndpointMetricsTool < BaseTool
      description "Get metric data for a specific endpoint"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:endpoint_id).filled(:string).description("Endpoint ID (base64 URL-encoded)")
        required(:metric_type).filled(:string).description("Metric type: apdex, response_time, response_time_95th, errors, throughput, queue_time")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
      end

      def call(app_id:, endpoint_id:, metric_type:, from: nil, to: nil)
        get_client.get_endpoint_metrics(app_id, endpoint_id, metric_type, from: from, to: to)
      end
    end

    class ListEndpointTracesTool < BaseTool
      description "List traces for a specific endpoint (max 100, within 7 days)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:endpoint_id).filled(:string).description("Endpoint ID (base64 URL-encoded)")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
      end

      def call(app_id:, endpoint_id:, from: nil, to: nil)
        get_client.list_endpoint_traces(app_id, endpoint_id, from: from, to: to)
      end
    end

    class FetchTraceTool < BaseTool
      description "Fetch detailed trace information from ScoutAPM API"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:trace_id).filled(:integer).description("Trace identifier")
        optional(:include_endpoint).filled(:bool).description("Also fetch endpoint details for context (default: false)")
      end

      def call(app_id:, trace_id:, include_endpoint: false)
        client = get_client
        result = {
          trace: client.fetch_trace(app_id, trace_id)
        }

        if include_endpoint
          trace_data = result[:trace]
          if trace_data.is_a?(Hash) && trace_data.dig("results", "trace", "metric_name")
            result[:trace_metric_name] = trace_data.dig("results", "trace", "metric_name")
          end
        end

        result
      end
    end

    # Errors Tools
    class ListErrorGroupsTool < BaseTool
      description "List error groups for an application (max 100, within 30 days)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
        optional(:endpoint).maybe(:string).description("Base64 URL-encoded endpoint filter (optional)")
      end

      def call(app_id:, from: nil, to: nil, endpoint: nil)
        get_client.list_error_groups(app_id, from: from, to: to, endpoint: endpoint)
      end
    end

    class GetErrorGroupTool < BaseTool
      description "Get details for a specific error group"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:error_id).filled(:integer).description("Error group identifier")
      end

      def call(app_id:, error_id:)
        get_client.get_error_group(app_id, error_id)
      end
    end

    class GetErrorGroupErrorsTool < BaseTool
      description "Get individual errors within an error group (max 100)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:error_id).filled(:integer).description("Error group identifier")
      end

      def call(app_id:, error_id:)
        get_client.get_error_group_errors(app_id, error_id)
      end
    end

    # Insights Tools
    class GetAllInsightsTool < BaseTool
      description "Get all insight types for an application (cached for 5 minutes)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:limit).maybe(:integer).description("Maximum number of items per insight type (default: 20)")
      end

      def call(app_id:, limit: nil)
        get_client.get_all_insights(app_id, limit: limit)
      end
    end

    class GetInsightByTypeTool < BaseTool
      description "Get data for a specific insight type"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:insight_type).filled(:string).description("Insight type: n_plus_one, memory_bloat, slow_query")
        optional(:limit).maybe(:integer).description("Maximum number of items (default: 20)")
      end

      def call(app_id:, insight_type:, limit: nil)
        get_client.get_insight_by_type(app_id, insight_type, limit: limit)
      end
    end

    class GetInsightsHistoryTool < BaseTool
      description "Get historical insights data with cursor-based pagination"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
        optional(:limit).maybe(:integer).description("Maximum number of items per page (default: 10)")
        optional(:pagination_cursor).maybe(:integer).description("Cursor for pagination (insight ID)")
        optional(:pagination_direction).maybe(:string).description("Pagination direction: forward, backward (default: forward)")
        optional(:pagination_page).maybe(:integer).description("Page number for pagination (default: 1)")
      end

      def call(app_id:, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
        get_client.get_insights_history(
          app_id,
          from: from,
          to: to,
          limit: limit,
          pagination_cursor: pagination_cursor,
          pagination_direction: pagination_direction,
          pagination_page: pagination_page
        )
      end
    end

    class GetInsightsHistoryByTypeTool < BaseTool
      description "Get historical insights data filtered by insight type with cursor-based pagination"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:insight_type).filled(:string).description("Insight type: n_plus_one, memory_bloat, slow_query")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
        optional(:limit).maybe(:integer).description("Maximum number of items per page (default: 10)")
        optional(:pagination_cursor).maybe(:integer).description("Cursor for pagination (insight ID)")
        optional(:pagination_direction).maybe(:string).description("Pagination direction: forward, backward (default: forward)")
        optional(:pagination_page).maybe(:integer).description("Page number for pagination (default: 1)")
      end

      def call(app_id:, insight_type:, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
        get_client.get_insights_history_by_type(
          app_id,
          insight_type,
          from: from,
          to: to,
          limit: limit,
          pagination_cursor: pagination_cursor,
          pagination_direction: pagination_direction,
          pagination_page: pagination_page
        )
      end
    end

    # Utility Tools
    class ParseScoutURLTool < BaseTool
      description "Parse a ScoutAPM URL and extract resource information (app_id, endpoint_id, trace_id, etc.)"

      arguments do
        required(:url).filled(:string).description("Full ScoutAPM URL (e.g., https://scoutapm.com/apps/123/endpoints/.../trace/456)")
      end

      def call(url:)
        Helpers.parse_scout_url(url)
      end
    end

    class FetchScoutURLTool < BaseTool
      description "Fetch data from a ScoutAPM URL by automatically detecting the resource type and fetching the appropriate data"

      arguments do
        required(:url).filled(:string).description("Full ScoutAPM URL (e.g., https://scoutapm.com/apps/123/endpoints/.../trace/456)")
        optional(:include_endpoint).filled(:bool).description("For trace URLs, also fetch endpoint details for context (default: false)")
      end

      def call(url:, include_endpoint: false)
        parsed = Helpers.parse_scout_url(url)
        client = get_client

        result = {
          url: url,
          parsed: parsed,
          data: nil
        }

        case parsed[:url_type]
        when :trace
          if parsed[:app_id] && parsed[:trace_id]
            trace_data = client.fetch_trace(parsed[:app_id], parsed[:trace_id])
            result[:data] = {trace: trace_data}

            if include_endpoint && parsed[:endpoint_id]
              endpoint_data = client.get_endpoint(parsed[:app_id], parsed[:endpoint_id])
              result[:data][:endpoint] = endpoint_data
              result[:data][:decoded_endpoint] = parsed[:decoded_endpoint]
            end
          else
            raise "Invalid trace URL: missing app_id or trace_id"
          end
        when :endpoint
          if parsed[:app_id] && parsed[:endpoint_id]
            endpoint_data = client.get_endpoint(parsed[:app_id], parsed[:endpoint_id])
            result[:data] = {
              endpoint: endpoint_data,
              decoded_endpoint: parsed[:decoded_endpoint]
            }
          else
            raise "Invalid endpoint URL: missing app_id or endpoint_id"
          end
        when :error_group
          if parsed[:app_id] && parsed[:error_id]
            error_data = client.get_error_group(parsed[:app_id], parsed[:error_id])
            result[:data] = {error_group: error_data}
          else
            raise "Invalid error group URL: missing app_id or error_id"
          end
        when :insight
          if parsed[:app_id]
            if parsed[:insight_type]
              insight_data = client.get_insight_by_type(parsed[:app_id], parsed[:insight_type])
              result[:data] = {insight: insight_data, insight_type: parsed[:insight_type]}
            else
              insights_data = client.get_all_insights(parsed[:app_id])
              result[:data] = {insights: insights_data}
            end
          else
            raise "Invalid insight URL: missing app_id"
          end
        when :app
          if parsed[:app_id]
            app_data = client.get_app(parsed[:app_id])
            result[:data] = {app: app_data}
          else
            raise "Invalid app URL: missing app_id"
          end
        when :unknown
          raise "Unknown or unsupported ScoutAPM URL format: #{url}"
        else
          raise "Unable to determine URL type from: #{url}"
        end

        result
      end
    end

    class FetchOpenAPISchemaTool < BaseTool
      description "Fetch the ScoutAPM OpenAPI schema from the API and optionally validate it"

      arguments do
        optional(:validate).filled(:bool).description("Validate the schema structure (default: false)")
        optional(:compare_with_local).filled(:bool).description("Compare with local schema file (tmp/scoutapm_openapi.yaml) (default: false)")
      end

      def call(validate: false, compare_with_local: false)
        api_key = Helpers.get_api_key
        client = Client.new(api_key: api_key)
        schema_data = client.fetch_openapi_schema

        result = {
          fetched: true,
          content_type: schema_data[:content_type],
          status: schema_data[:status],
          content_length: schema_data[:content].length
        }

        if validate
          begin
            require "yaml"
            parsed = YAML.safe_load(schema_data[:content])
            result[:valid_yaml] = true
            result[:openapi_version] = parsed["openapi"] if parsed.is_a?(Hash)
            result[:info] = parsed["info"] if parsed.is_a?(Hash) && parsed["info"]
          rescue => e
            result[:valid_yaml] = false
            result[:validation_error] = e.message
          end
        end

        if compare_with_local
          local_schema_path = File.expand_path("tmp/scoutapm_openapi.yaml")
          if File.exist?(local_schema_path)
            local_content = File.read(local_schema_path)
            result[:local_file_exists] = true
            result[:local_file_length] = local_content.length
            result[:content_matches] = (schema_data[:content] == local_content)

            unless result[:content_matches]
              begin
                require "yaml"
                remote_parsed = YAML.safe_load(schema_data[:content])
                local_parsed = YAML.safe_load(local_content)
                result[:structure_matches] = (remote_parsed == local_parsed)
                result[:remote_paths_count] = remote_parsed.dig("paths")&.keys&.length if remote_parsed.is_a?(Hash)
                result[:local_paths_count] = local_parsed.dig("paths")&.keys&.length if local_parsed.is_a?(Hash)
              rescue => e
                result[:comparison_error] = e.message
              end
            end
          else
            result[:local_file_exists] = false
          end
        end

        # Include a preview of the content (first 500 chars) for inspection
        result[:content_preview] = schema_data[:content][0..500] if schema_data[:content]

        result
      end
    end
  end
end
