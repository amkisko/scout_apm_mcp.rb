require "securerandom"

# Monkey-patch fast-mcp so JSON-RPC error responses always include a non-nil id (strict MCP clients).
# Loaded from server only; excluded.from SimpleCov — see spec_helper.
module MCP
  module Transports
    class StdioTransport
      if method_defined?(:send_error)
        alias_method :original_send_error, :send_error

        def send_error(code, message, id = nil)
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
        id = "error_#{SecureRandom.hex(8)}" if id.nil?
        original_send_error(code, message, id)
      end
    end
  end
end
