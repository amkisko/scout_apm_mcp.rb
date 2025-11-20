require "uri"
require "base64"

require_relative "scout_apm_mcp/version"
require_relative "scout_apm_mcp/client"
require_relative "scout_apm_mcp/helpers"
# Server is loaded on-demand when running the executable
# require_relative "scout_apm_mcp/server"

module ScoutApmMcp
  # Main module for ScoutAPM MCP integration
  #
  # This gem provides:
  # - ScoutApmMcp::Client - API client for ScoutAPM
  # - ScoutApmMcp::Helpers - Helper methods for API key management and URL parsing
  #
  # @example Basic usage
  #   require "scout_apm_mcp"
  #
  #   # Get API key
  #   api_key = ScoutApmMcp::Helpers.get_api_key
  #
  #   # Create client
  #   client = ScoutApmMcp::Client.new(api_key: api_key)
  #
  #   # List applications
  #   apps = client.list_apps
  #
  #   # Fetch trace
  #   trace = client.fetch_trace(123, 456)
  #
  # @example Parse ScoutAPM URL
  #   url = "https://scoutapm.com/apps/123/endpoints/.../trace/456"
  #   parsed = ScoutApmMcp::Helpers.parse_scout_url(url)
  #   # => { app_id: 123, endpoint_id: "...", trace_id: 456, ... }
end
