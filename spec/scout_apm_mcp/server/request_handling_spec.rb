# frozen_string_literal: true

require "spec_helper"
require "scout_apm_mcp/server"
require "scout_apm_mcp/server/shared_contexts"
require "json"

RSpec.describe ScoutApmMcp::Server do
  include_context "with server integration"

  def parse_response(io_response)
    io_response.rewind
    JSON.parse(io_response.read)
  end

  describe "request handling" do
    it "responds to ping requests" do
      io_response = with_captured_stdout { server.handle_request(JSON.generate({jsonrpc: "2.0", method: "ping", id: 1})) }
      io_as_json = parse_response(io_response)

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(io_as_json["result"]).to eq({})
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "responds to initialize requests" do
      request = {jsonrpc: "2.0", method: "initialize", id: 1, params: {protocolVersion: "2024-11-05", capabilities: {}, clientInfo: {name: "test-client", version: "1.0.0"}}}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      server_info = io_as_json["result"]["serverInfo"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(server_info["name"]).to eq("scout-apm")
        expect(server_info["version"]).to eq(ScoutApmMcp::VERSION)
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "responds nil to notifications/initialized requests" do
      io_response = with_captured_stdout { server.handle_request(JSON.generate({jsonrpc: "2.0", method: "notifications/initialized"})) }

      expect(io_response).to be_nil
    end

    it "lists tools" do
      request = {jsonrpc: "2.0", method: "tools/list", id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      tools = io_as_json["result"]["tools"]
      tool_names = tools.map { |t| t["name"] }

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(tools).to be_an(Array)
        expect(tools.length).to be > 0
        expect(tool_names).to include("ScoutApmMcpServerListAppsTool", "ScoutApmMcpServerGetAppTool", "ScoutApmMcpServerParseScoutURLTool")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "calls list_apps tool" do
      mock_client = instance_double(ScoutApmMcp::Client)
      allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:list_apps).and_return([{"id" => 1, "name" => "Test App"}])

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerListAppsTool", arguments: {}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      content = io_as_json["result"]["content"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(content).to be_an(Array)
        expect(content[0]["text"]).to include("Test App")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "calls get_app tool" do
      mock_client = instance_double(ScoutApmMcp::Client)
      allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:get_app).with(123).and_return({"id" => 123, "name" => "Test App"})

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerGetAppTool", arguments: {app_id: 123}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      content = io_as_json["result"]["content"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(content).to be_an(Array)
        expect(content[0]["text"]).to include("Test App")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "calls parse_scout_url tool" do
      url = "https://scoutapm.com/apps/123/endpoints/abc123/trace/456"
      parsed_result = {app_id: 123, url_type: :trace, endpoint_id: "abc123", trace_id: 456}
      allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).with(url).and_return(parsed_result)

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerParseScoutURLTool", arguments: {url: url}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      content = io_as_json["result"]["content"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(content).to be_an(Array)
        expect(content[0]["text"]).to include("trace")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "handles errors for unknown methods" do
      request = {jsonrpc: "2.0", method: "unknown", id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      error = io_as_json["error"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(error["code"]).to eq(-32_601)
        expect(error["message"]).to include("Method not found")
        expect(io_as_json["id"]).to be_truthy
      end
    end

    it "handles errors for invalid JSON requests" do
      request = 1
      io_response = with_captured_stdout { server.handle_request(request) }
      io_as_json = parse_response(io_response)
      error = io_as_json["error"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(error["code"]).to eq(-32_600)
        expect(error["message"]).to include("Invalid Request")
        expect(io_as_json["id"]).to be_truthy.or(be_nil)
      end
    end

    it "handles errors for invalid JSON-RPC 2.0 requests" do
      request = {id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      error = io_as_json["error"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(error["code"]).to eq(-32_600)
        expect(error["message"]).to include("Invalid Request")
        expect(io_as_json["id"]).to be_truthy
      end
    end

    it "handles tool errors gracefully" do
      mock_client = instance_double(ScoutApmMcp::Client)
      allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
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

    it "handles missing required arguments" do
      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerGetAppTool", arguments: {}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      result = io_as_json["result"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(result["isError"]).to be true
        expect(result["content"][0]["text"]).to include("app_id")
        expect(io_as_json["id"]).to eq(1)
      end
    end
  end
end
