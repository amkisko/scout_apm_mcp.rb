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

    def self.register_tools(server)
      server.register_tool(ListAppsTool)
      server.register_tool(GetAppTool)
      server.register_tool(ListMetricsTool)
      server.register_tool(GetMetricTool)
      server.register_tool(ListEndpointsTool)
      server.register_tool(GetEndpointMetricsTool)
      server.register_tool(ListEndpointTracesTool)
      server.register_tool(ListJobsTool)
      server.register_tool(ListJobMetricsTool)
      server.register_tool(GetJobMetricsTool)
      server.register_tool(ListJobTracesTool)
      server.register_tool(FetchTraceTool)
      server.register_tool(ListErrorGroupsTool)
      server.register_tool(GetErrorGroupTool)
      server.register_tool(GetErrorGroupErrorsTool)
      server.register_tool(ListAnomalyEventsTool)
      server.register_tool(GetAnomalyEventTool)
      server.register_tool(GetAllInsightsTool)
      server.register_tool(GetInsightByTypeTool)
      server.register_tool(GetInsightsHistoryTool)
      server.register_tool(GetInsightsHistoryByTypeTool)
      server.register_tool(ParseScoutURLTool)
      server.register_tool(FetchScoutURLTool)
      server.register_tool(FetchOpenAPISchemaTool)
    end
  end
end
