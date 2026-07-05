require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#list_anomaly_events" do
    it "makes a GET request to /apps/:app_id/anomaly_events and returns anomaly events array" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/anomaly_events")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"anomaly_events": [{"id": 1}]}}')

      result = client.list_anomaly_events(app_id)
      expect(result).to eq([{"id" => 1}])
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/anomaly_events?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}&state=open&metric=response_time&endpoint=UsersController%23index")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"anomaly_events": []}}')

      result = client.list_anomaly_events(
        app_id,
        from: from,
        to: to,
        state: "open",
        metric: "response_time",
        endpoint: "UsersController#index"
      )
      expect(result).to eq([])
    end

    it "validates state filter" do
      expect {
        client.list_anomaly_events(123, state: "invalid")
      }.to raise_error(ArgumentError, /Invalid state/)
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      to_time = "2025-01-15T12:00:00Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/anomaly_events/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"anomaly_events": []}}')

      result = client.list_anomaly_events(app_id, range: "1day", to: to_time)
      expect(result).to eq([])
    end
  end

  describe "#get_anomaly_event" do
    it "makes a GET request to /apps/:app_id/anomaly_events/:anomaly_event_id and returns anomaly event hash" do
      app_id = 123
      anomaly_event_id = 456
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/anomaly_events/#{anomaly_event_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"anomaly_event": {"id": 456, "metric": "response_time"}}}')

      result = client.get_anomaly_event(app_id, anomaly_event_id)
      expect(result).to eq({"id" => 456, "metric" => "response_time"})
    end
  end
end
