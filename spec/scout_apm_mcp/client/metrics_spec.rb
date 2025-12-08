require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#list_metrics" do
    it "makes a GET request to /apps/:app_id/metrics and returns metrics array" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"availableMetrics": ["response_time", "throughput"]}}')

      result = client.list_metrics(app_id)
      expect(result).to eq(["response_time", "throughput"])
    end

    it "returns empty array when no metrics" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.list_metrics(app_id)
      expect(result).to eq([])
    end
  end

  describe "#get_metric" do
    it "makes a GET request to /apps/:app_id/metrics/:metric_type and returns series hash" do
      app_id = 123
      metric_type = "response_time"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"series": {"response_time": [[1234567890, 100.5]]}}}')

      result = client.get_metric(app_id, metric_type)
      expect(result).to eq({"response_time" => [[1234567890, 100.5]]})
    end

    it "includes query parameters when provided" do
      app_id = 123
      metric_type = "response_time"
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics/#{metric_type}?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"series": {}}}')

      result = client.get_metric(app_id, metric_type, from: from, to: to)
      expect(result).to eq({})
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      metric_type = "response_time"
      to_time = "2025-01-15T12:00:00Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/metrics\/#{metric_type}/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"series": {}}}')

      result = client.get_metric(app_id, metric_type, range: "3hrs", to: to_time)
      expect(result).to eq({})
    end

    it "validates metric type" do
      app_id = 123
      expect {
        client.get_metric(app_id, "invalid_metric")
      }.to raise_error(ArgumentError, /Invalid metric_type/)
    end

    it "validates time range" do
      app_id = 123
      from = "2025-01-02T00:00:00Z"
      to = "2025-01-01T00:00:00Z"
      expect {
        client.get_metric(app_id, "response_time", from: from, to: to)
      }.to raise_error(ArgumentError, /from_time must be before to_time/)
    end

    it "validates time range does not exceed 2 weeks" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-20T00:00:00Z" # 19 days
      expect {
        client.get_metric(app_id, "response_time", from: from, to: to)
      }.to raise_error(ArgumentError, /Time range cannot exceed 2 weeks/)
    end
  end
end
