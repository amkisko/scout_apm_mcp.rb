module ScoutApmMcp
  class Server
    class BaseTool < FastMcp::Tool
      protected

      def get_client
        ScoutApmMcp::Server.api_client
      end
    end
  end
end
