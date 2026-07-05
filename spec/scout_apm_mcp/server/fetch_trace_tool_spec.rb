require "spec_helper"
require "scout_apm_mcp/server"
require "scout_apm_mcp/server/shared_contexts"
require "json"

RSpec.describe ScoutApmMcp::Server, "#handle_request" do
  include_context "with server integration"

  let(:mock_client) { instance_double(ScoutApmMcp::Client) }

  before do
    allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
  end

  def parse_response(io_response)
    io_response.rewind
    JSON.parse(io_response.read)
  end

  def call_fetch_trace(include_endpoint: false)
    req = {
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: "ScoutApmMcpServerFetchTraceTool",
        arguments: {app_id: 10, trace_id: 55, include_endpoint: include_endpoint}
      },
      id: 1
    }
    io_response = with_captured_stdout { server.handle_request(JSON.generate(req)) }
    parse_response(io_response)
  end

  it "includes trace_metric_name when include_endpoint is true and the trace has metric_name" do
    allow(mock_client).to receive(:fetch_trace).with(10, 55).and_return(
      {"id" => 55, "metric_name" => "UsersController#index"}
    )

    res = call_fetch_trace(include_endpoint: true)
    text = res.dig("result", "content", 0, "text")

    aggregate_failures do
      expect(res.dig("result", "isError")).not_to be true
      expect(text).to include("trace_metric_name")
      expect(text).to include("UsersController#index")
    end
  end

  it "omits trace_metric_name when include_endpoint is false" do
    allow(mock_client).to receive(:fetch_trace).with(10, 55).and_return(
      {"id" => 55, "metric_name" => "UsersController#index"}
    )

    res = call_fetch_trace(include_endpoint: false)
    text = res.dig("result", "content", 0, "text")

    aggregate_failures do
      expect(res.dig("result", "isError")).not_to be true
      expect(text).not_to include("trace_metric_name")
    end
  end
end
