require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#list_endpoints" do
    it "makes a GET request to /apps/:app_id/endpoints and returns endpoints array" do
      app_id = 123
      # Default behavior now includes 7-day range, so we need to stub with query params
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/endpoints/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": [{"id": 1, "name": "/test"}]}')

      result = client.list_endpoints(app_id)
      expect(result).to eq([{"id" => 1, "name" => "/test"}])
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_endpoints(app_id, from: from, to: to)
      expect(result).to eq([])
    end

    it "validates time range" do
      app_id = 123
      from = "2025-01-02T00:00:00Z"
      to = "2025-01-01T00:00:00Z"
      expect {
        client.list_endpoints(app_id, from: from, to: to)
      }.to raise_error(ArgumentError, /from_time must be before to_time/)
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      to_time = "2025-01-15T12:00:00Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/endpoints/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_endpoints(app_id, range: "1day", to: to_time)
      expect(result).to eq([])
    end
  end

  describe "#get_endpoint_metrics" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id/metrics/:metric_type and returns metric array" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      metric_type = "response_time"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"series": {"response_time": [[1234567890, 100.5]]}}}')

      result = client.get_endpoint_metrics(app_id, endpoint_id, metric_type)
      expect(result).to eq([[1234567890, 100.5]])
    end

    it "includes query parameters when provided" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      metric_type = "response_time"
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      encoded_id = CGI.escape(endpoint_id)
      url = "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/metrics/#{metric_type}?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}"
      stub_request(:get, url).with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"}).to_return(status: 200, body: '{"results": {"series": {}}}')

      result = client.get_endpoint_metrics(app_id, endpoint_id, metric_type, from: from, to: to)
      expect(result).to eq([])
    end

    it "validates metric type" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      expect {
        client.get_endpoint_metrics(app_id, endpoint_id, "invalid_metric")
      }.to raise_error(ArgumentError, /Invalid metric_type/)
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      metric_type = "response_time"
      to_time = "2025-01-15T12:00:00Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/endpoints\/#{endpoint_id}\/metrics\/#{metric_type}/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"series": {"response_time": []}}}')

      result = client.get_endpoint_metrics(app_id, endpoint_id, metric_type, range: "6hrs", to: to_time)
      expect(result).to eq([])
    end
  end

  describe "#list_endpoint_traces" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id/traces and returns traces array" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/traces")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"traces": [{"id": 1}]}}')

      result = client.list_endpoint_traces(app_id, endpoint_id)
      expect(result).to eq([{"id" => 1}])
    end

    it "includes query parameters when provided" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      # Use recent dates (within 7 days) to avoid validation error
      from = (Time.now.utc - (1 * 24 * 60 * 60)).strftime("%Y-%m-%dT%H:%M:%SZ")
      to = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/traces?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"traces": []}}')

      result = client.list_endpoint_traces(app_id, endpoint_id, from: from, to: to)
      expect(result).to eq([])
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      to_time = "2025-12-08T11:51:42Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/endpoints\/#{endpoint_id}\/traces/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"traces": []}}')

      result = client.list_endpoint_traces(app_id, endpoint_id, range: "12hrs", to: to_time)
      expect(result).to eq([])
    end

    it "validates that from_time is not older than 7 days" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      from = (Time.now.utc - (8 * 24 * 60 * 60)).strftime("%Y-%m-%dT%H:%M:%SZ")
      to = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      expect {
        client.list_endpoint_traces(app_id, endpoint_id, from: from, to: to)
      }.to raise_error(ArgumentError, /from_time cannot be older than 7 days/)
    end
  end
end
