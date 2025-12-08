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

  describe "tool integration" do
    it "calls list_endpoints with default timeframe" do
      allow(mock_client).to receive(:list_endpoints).and_return([{"id" => 1, "name" => "/test"}])

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerListEndpointsTool", arguments: {app_id: 123}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(io_as_json["result"]["content"]).to be_an(Array)
        expect(mock_client).to have_received(:list_endpoints).with(123, hash_including(from: anything, to: anything))
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "calls get_metric with range parameter" do
      allow(mock_client).to receive(:get_metric).and_return({"response_time" => [[1_234_567_890, 100.5]]})

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerGetMetricTool", arguments: {app_id: 123, metric_type: "response_time", range: "1day"}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(io_as_json["result"]["content"]).to be_an(Array)
        expect(mock_client).to have_received(:get_metric).with(123, "response_time", hash_including(range: "1day"))
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "calls fetch_scout_url tool for endpoint URL" do
      url = "https://scoutapm.com/apps/123/endpoints/abc123"
      parsed_result = {app_id: 123, url_type: :endpoint, endpoint_id: "abc123", decoded_endpoint: "Controller/Test/POST"}
      endpoint_data = {"id" => 1, "name" => "/test", "link" => "/apps/123/endpoints/abc123"}
      allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).with(url).and_return(parsed_result)
      allow(mock_client).to receive(:list_endpoints).with(123, hash_including(range: "7days")).and_return([endpoint_data])
      allow(ScoutApmMcp::Helpers).to receive(:get_endpoint_id).with(endpoint_data).and_return("abc123")

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerFetchScoutURLTool", arguments: {url: url}}, id: 1}
      io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
      io_as_json = parse_response(io_response)
      content = io_as_json["result"]["content"]

      aggregate_failures do
        expect(io_as_json["jsonrpc"]).to eq("2.0")
        expect(content).to be_an(Array)
        expect(content[0]["text"]).to include("endpoint")
        expect(io_as_json["id"]).to eq(1)
      end
    end

    it "calls fetch_scout_url tool for trace URL" do
      url = "https://scoutapm.com/apps/123/endpoints/abc123/trace/456"
      parsed_result = {app_id: 123, url_type: :trace, endpoint_id: "abc123", trace_id: 456}
      trace_data = {"id" => 456, "spans" => []}
      allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).with(url).and_return(parsed_result)
      allow(mock_client).to receive(:fetch_trace).with(123, 456).and_return(trace_data)

      request = {jsonrpc: "2.0", method: "tools/call", params: {name: "ScoutApmMcpServerFetchScoutURLTool", arguments: {url: url}}, id: 1}
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
  end
end
