# frozen_string_literal: true

require "spec_helper"
require "scout_apm_mcp/server"
require "scout_apm_mcp/server/shared_contexts"
require "json"

RSpec.describe ScoutApmMcp::Server do
  include_context "with server integration"

  let(:mock_client) { instance_double(ScoutApmMcp::Client) }

  before do
    allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
  end

  def parse_response(io_response)
    io_response.rewind
    JSON.parse(io_response.read)
  end

  describe "error handling" do
    it "handles authentication errors" do
      allow(mock_client).to receive(:list_apps).and_raise(ScoutApmMcp::AuthError.new("Authentication failed"))

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerListAppsTool", arguments: {}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      result = io_as_json["result"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(result["isError"]).to be true
        expect(result["content"][0]["text"]).to include("Authentication failed")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "handles API errors" do
      allow(mock_client).to receive(:get_app).and_raise(ScoutApmMcp::APIError.new("Resource not found", status_code: 404))

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerGetAppTool", arguments: {app_id: 999}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      result = io_as_json["result"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(result["isError"]).to be true
        expect(result["content"][0]["text"]).to include("Resource not found")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "handles generic errors" do
      allow(mock_client).to receive(:list_apps).and_raise(StandardError.new("Unexpected error"))

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerListAppsTool", arguments: {}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      result = io_as_json["result"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(result["isError"]).to be true
        expect(result["content"][0]["text"]).to include("Unexpected error")
        expect(io_as_json["id"]).to eq(1)
      end
    end
  end
end
