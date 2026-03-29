require "spec_helper"
require "scout_apm_mcp/server"
require "scout_apm_mcp/server/shared_contexts"
require "json"

RSpec.describe ScoutApmMcp::Server, "#handle_request" do
  include_context "with server integration"

  let(:mock_client) { instance_double(ScoutApmMcp::Client) }

  before do
    allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive_messages(
      list_apps: [],
      get_app: {},
      list_metrics: [],
      get_metric: {},
      list_endpoints: [],
      get_endpoint_metrics: [],
      list_endpoint_traces: [],
      list_jobs: [],
      list_job_metrics: [],
      get_job_metrics: [],
      list_job_traces: [],
      fetch_trace: {"id" => 1},
      list_error_groups: [],
      get_error_group: {},
      get_error_group_errors: [],
      get_all_insights: {},
      get_insight_by_type: {},
      get_insights_history: {},
      get_insights_history_by_type: {},
      fetch_openapi_schema: {content: "openapi: 3.0.3\n", content_type: "application/x-yaml", status: 200}
    )
  end

  def parse_response(io_response)
    io_response.rewind
    JSON.parse(io_response.read)
  end

  def call_tool(name, arguments)
    request = {jsonrpc: "2.0", method: "tools/call", params: {name: name, arguments: arguments}, id: 1}
    io_response = with_captured_stdout { server.handle_request(JSON.generate(request)) }
    parse_response(io_response)
  end

  it "dispatches every registered tool successfully" do
    list_req = {jsonrpc: "2.0", method: "tools/list", id: 1}
    io_response = with_captured_stdout { server.handle_request(JSON.generate(list_req)) }
    tool_names = parse_response(io_response).dig("result", "tools").map { |t| t["name"] }

    calls = {
      "ScoutApmMcpServerListAppsTool" => {},
      "ScoutApmMcpServerGetAppTool" => {app_id: 1},
      "ScoutApmMcpServerListMetricsTool" => {app_id: 1},
      "ScoutApmMcpServerGetMetricTool" => {app_id: 1, metric_type: "response_time", range: "1day"},
      "ScoutApmMcpServerListEndpointsTool" => {app_id: 1, range: "7days"},
      "ScoutApmMcpServerGetEndpointMetricsTool" => {app_id: 1, endpoint_id: "e", metric_type: "throughput", range: "1day"},
      "ScoutApmMcpServerListEndpointTracesTool" => {app_id: 1, endpoint_id: "e", range: "1day"},
      "ScoutApmMcpServerListJobsTool" => {app_id: 1, range: "7days"},
      "ScoutApmMcpServerListJobMetricsTool" => {app_id: 1, job_id: "j"},
      "ScoutApmMcpServerGetJobMetricsTool" => {app_id: 1, job_id: "j", metric_type: "latency", range: "1day"},
      "ScoutApmMcpServerListJobTracesTool" => {app_id: 1, job_id: "j", range: "1day"},
      "ScoutApmMcpServerFetchTraceTool" => {app_id: 1, trace_id: 9, include_endpoint: true},
      "ScoutApmMcpServerListErrorGroupsTool" => {app_id: 1},
      "ScoutApmMcpServerGetErrorGroupTool" => {app_id: 1, error_id: 2},
      "ScoutApmMcpServerGetErrorGroupErrorsTool" => {app_id: 1, error_id: 2},
      "ScoutApmMcpServerGetAllInsightsTool" => {app_id: 1},
      "ScoutApmMcpServerGetInsightByTypeTool" => {app_id: 1, insight_type: "n_plus_one"},
      "ScoutApmMcpServerGetInsightsHistoryTool" => {app_id: 1},
      "ScoutApmMcpServerGetInsightsHistoryByTypeTool" => {app_id: 1, insight_type: "slow_query"},
      "ScoutApmMcpServerParseScoutURLTool" => {url: "https://scoutapm.com/apps/1"},
      "ScoutApmMcpServerFetchScoutURLTool" => {url: "https://scoutapm.com/apps/1"},
      "ScoutApmMcpServerFetchOpenAPISchemaTool" => {validate: true, compare_with_local: false}
    }

    deep_trace = {"results" => {"trace" => {"metric_name" => "Worker#perform"}}}
    allow(mock_client).to receive(:fetch_trace).and_return(deep_trace)

    aggregate_failures do
      expect(tool_names).to include(*calls.keys)

      calls.each do |tool_name, args|
        res = call_tool(tool_name, args)
        expect(res["error"]).to be_nil, -> { "tool #{tool_name} failed: #{res.inspect}" }
        expect(res.dig("result", "content")).to be_an(Array), -> { "tool #{tool_name} missing content: #{res.inspect}" }
      end
    end
  end
end
