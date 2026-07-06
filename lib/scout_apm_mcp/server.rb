#!/usr/bin/env ruby
require "fast_mcp"
require "scout_apm_mcp"
require "logger"
require "stringio"
require_relative "mcp_error_id_patch"
require_relative "server/null_logger"
require_relative "server/base_tool"
require_relative "server/tools/standard_tools"
require_relative "server/tools/parse_scout_url_tool"
require_relative "server/tools/fetch_scout_url_tool"
require_relative "server/tools/fetch_openapi_schema_tool"

module ScoutApmMcp
  # MCP Server for ScoutAPM integration
  #
  # This server provides MCP tools for interacting with ScoutAPM API
  # Usage: bundle exec scout_apm_mcp
  class Server
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

    def self.api_client
      @api_client ||= Client.new(api_key: Helpers.get_api_key)
    end

    TOOL_CLASSES = [
      ListAppsTool,
      GetAppTool,
      ListMetricsTool,
      GetMetricTool,
      ListEndpointsTool,
      GetEndpointMetricsTool,
      ListEndpointTracesTool,
      ListJobsTool,
      ListJobMetricsTool,
      GetJobMetricsTool,
      ListJobTracesTool,
      FetchTraceTool,
      ListErrorGroupsTool,
      GetErrorGroupTool,
      GetErrorGroupErrorsTool,
      ListAnomalyEventsTool,
      GetAnomalyEventTool,
      GetAllInsightsTool,
      GetInsightByTypeTool,
      GetInsightsHistoryTool,
      GetInsightsHistoryByTypeTool,
      ParseScoutURLTool,
      FetchScoutURLTool,
      FetchOpenAPISchemaTool
    ].freeze

    def self.register_tools(server)
      TOOL_CLASSES.each { |tool_class| server.register_tool(tool_class) }
    end
  end
end
