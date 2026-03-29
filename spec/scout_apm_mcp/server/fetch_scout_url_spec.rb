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
      fetch_trace: {"id" => 1},
      get_app: {},
      get_error_group: {},
      get_insight_by_type: {},
      get_all_insights: {},
      list_endpoints: [],
      list_jobs: []
    )
  end

  def parse_response(io_response)
    io_response.rewind
    JSON.parse(io_response.read)
  end

  def call_fetch(url, include_endpoint: false)
    req = {
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: "ScoutApmMcpServerFetchScoutURLTool",
        arguments: {url: url, include_endpoint: include_endpoint}
      },
      id: 1
    }
    io_response = with_captured_stdout { server.handle_request(JSON.generate(req)) }
    parse_response(io_response)
  end

  it "adds endpoint context when requested and the endpoint exists" do
    ep_id = Base64.urlsafe_encode64("UsersController#index")
    url = "https://scoutapm.com/apps/10/endpoints/#{ep_id}/trace/55"
    ep_row = {"link" => "/apps/10/endpoints/#{ep_id}", "name" => "UsersController#index"}
    allow(mock_client).to receive(:list_endpoints).with(10, hash_including(range: "7days")).and_return([ep_row])

    res = call_fetch(url, include_endpoint: true)
    aggregate_failures do
      expect(res.dig("result", "isError")).not_to be true
      expect(res.dig("result", "content", 0, "text")).to include("UsersController")
    end
  end

  it "records endpoint_error when the endpoint is missing from recent data" do
    ep_id = Base64.urlsafe_encode64("Ghost#index")
    url = "https://scoutapm.com/apps/10/endpoints/#{ep_id}/trace/55"
    allow(mock_client).to receive(:list_endpoints).with(10, hash_including(range: "7days")).and_return([])

    res = call_fetch(url, include_endpoint: true)
    expect(res.dig("result", "content", 0, "text")).to include("endpoint_error")
  end

  it "records endpoint_error when list_endpoints raises" do
    ep_id = Base64.urlsafe_encode64("X#y")
    url = "https://scoutapm.com/apps/10/endpoints/#{ep_id}/trace/55"
    allow(mock_client).to receive(:list_endpoints).and_raise(StandardError.new("network"))

    res = call_fetch(url, include_endpoint: true)
    expect(res.dig("result", "content", 0, "text")).to include("Failed to fetch endpoint")
  end

  it "adds job context for job trace URLs when requested" do
    jid = Base64.urlsafe_encode64("default/MyWorker")
    url = "https://scoutapm.com/apps/10/jobs/#{jid}/trace/77"
    allow(mock_client).to receive(:list_jobs).with(10, hash_including(range: "7days")).and_return([{"job_id" => jid, "name" => "MyWorker"}])

    res = call_fetch(url, include_endpoint: true)
    expect(res.dig("result", "content", 0, "text")).to include("MyWorker")
  end

  it "records job_error when the job is missing" do
    jid = Base64.urlsafe_encode64("default/Missing")
    url = "https://scoutapm.com/apps/10/jobs/#{jid}/trace/77"

    res = call_fetch(url, include_endpoint: true)
    expect(res.dig("result", "content", 0, "text")).to include("job_error")
  end

  it "records job_error when list_jobs raises" do
    jid = Base64.urlsafe_encode64("default/MyWorker")
    url = "https://scoutapm.com/apps/10/jobs/#{jid}/trace/77"
    allow(mock_client).to receive(:list_jobs).and_raise(StandardError.new("timeout"))

    res = call_fetch(url, include_endpoint: true)
    expect(res.dig("result", "content", 0, "text")).to include("Failed to fetch job")
  end

  it "fetches a job summary from a job URL" do
    jid = Base64.urlsafe_encode64("default/MyWorker")
    url = "https://scoutapm.com/apps/10/jobs/#{jid}"
    allow(mock_client).to receive(:list_jobs).and_return([{"job_id" => jid, "name" => "MyWorker"}])

    res = call_fetch(url)
    expect(res.dig("result", "content", 0, "text")).to include("MyWorker")
  end

  it "returns MCP error when the job URL does not match recent jobs data" do
    jid = Base64.urlsafe_encode64("default/MyWorker")
    url = "https://scoutapm.com/apps/10/jobs/#{jid}"

    res = call_fetch(url)
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Job not found")
    end
  end

  it "returns MCP error when the endpoint URL does not match recent endpoints" do
    ep_id = Base64.urlsafe_encode64("Missing#index")
    url = "https://scoutapm.com/apps/10/endpoints/#{ep_id}"

    res = call_fetch(url)
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Endpoint not found")
    end
  end

  it "returns MCP error for invalid error group URLs" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :error_group, app_id: 1})

    res = call_fetch("https://example.test/invalid")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid error group URL")
    end
  end

  it "returns MCP error for insight URLs without app_id" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :insight, insight_type: "n_plus_one"})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid insight URL")
    end
  end

  it "returns MCP error for app URLs without app_id" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :app})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid app URL")
    end
  end

  it "returns MCP error for unknown URL types from parse_scout_url" do
    res = call_fetch("https://scoutapm.com/apps/999/unknown/segment")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Unknown or unsupported")
    end
  end

  it "returns MCP error when parse_scout_url yields no url_type" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({app_id: 1})

    res = call_fetch("https://example.test/orphan")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Unable to determine URL type")
    end
  end

  it "returns MCP error for malformed job trace URLs missing ids" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :job_trace, app_id: 1})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid job trace URL")
    end
  end

  it "returns MCP error for malformed endpoint traces missing ids" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :trace, app_id: 1, endpoint_id: "e"})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid trace URL")
    end
  end

  it "loads all insights when an insight URL has no specific type" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :insight, app_id: 42})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).not_to be true
      expect(mock_client).to have_received(:get_all_insights).with(42)
    end
  end

  it "returns MCP error for job URLs missing job_id" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :job, app_id: 1})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid job URL")
    end
  end

  it "returns MCP error for endpoint URLs missing endpoint_id" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :endpoint, app_id: 1})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).to be true
      expect(res.dig("result", "content", 0, "text")).to include("Invalid endpoint URL")
    end
  end

  it "fetches error group details when ids are present" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :error_group, app_id: 7, error_id: 99})
    allow(mock_client).to receive(:get_error_group).with(7, 99).and_return({"id" => 99})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).not_to be true
      expect(res.dig("result", "content", 0, "text")).to include("error_group")
    end
  end

  it "fetches insight by type when insight_type is present" do
    allow(ScoutApmMcp::Helpers).to receive(:parse_scout_url).and_return({url_type: :insight, app_id: 8, insight_type: "slow_query"})
    allow(mock_client).to receive(:get_insight_by_type).with(8, "slow_query").and_return({"items" => []})

    res = call_fetch("https://example.test/x")
    aggregate_failures do
      expect(res.dig("result", "isError")).not_to be true
      expect(mock_client).to have_received(:get_insight_by_type).with(8, "slow_query")
    end
  end
end
