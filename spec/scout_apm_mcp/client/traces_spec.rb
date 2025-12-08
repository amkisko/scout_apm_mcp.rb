require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#fetch_trace" do
    it "makes a GET request to /apps/:app_id/traces/:trace_id and returns trace hash" do
      app_id = 123
      trace_id = 456
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/traces/#{trace_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"trace": {"id": 456, "spans": []}}}')

      result = client.fetch_trace(app_id, trace_id)
      expect(result).to eq({"id" => 456, "spans" => []})
    end
  end
end
