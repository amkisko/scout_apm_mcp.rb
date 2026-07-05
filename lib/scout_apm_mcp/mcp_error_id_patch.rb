require "securerandom"

# Monkey-patch fast-mcp so JSON-RPC error responses always include a non-nil id (strict MCP clients).
# Loaded from server only; excluded from SimpleCov — see spec_helper.
module ScoutApmMcp
  module McpErrorIdPatch
    def self.apply!(target)
      return unless target.private_method_defined?(:send_error) || target.method_defined?(:send_error)

      target.class_eval do
        alias_method :original_send_error, :send_error

        define_method(:send_error) do |code, message, id = nil|
          id = "error_#{SecureRandom.hex(8)}" if id.nil?
          original_send_error(code, message, id)
        end
      end
    end
  end
end

ScoutApmMcp::McpErrorIdPatch.apply!(FastMcp::Server)
ScoutApmMcp::McpErrorIdPatch.apply!(FastMcp::Transports::StdioTransport)
