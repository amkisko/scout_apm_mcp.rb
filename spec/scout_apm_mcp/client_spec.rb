require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#initialize" do
    it "sets the API key" do
      expect(client.instance_variable_get(:@api_key)).to eq(api_key)
    end

    it "uses default API base URL" do
      expect(client.instance_variable_get(:@api_base)).to eq("https://scoutapm.com/api/v0")
    end

    it "allows custom API base URL" do
      custom_base = "https://custom.example.com/api"
      client = described_class.new(api_key: api_key, api_base: custom_base)
      expect(client.instance_variable_get(:@api_base)).to eq(custom_base)
    end
  end

  describe "#list_apps" do
    it "makes a GET request to /apps and returns apps array" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"apps": [{"id": 1, "name": "Test App"}]}}')

      result = client.list_apps
      expect(result).to eq([{"id" => 1, "name" => "Test App"}])
    end

    it "filters apps by active_since" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"apps": [{"id": 1, "name": "Active App", "last_reported_at": "2025-01-15T00:00:00Z"}, {"id": 2, "name": "Inactive App", "last_reported_at": "2025-01-01T00:00:00Z"}]}}')

      result = client.list_apps(active_since: "2025-01-10T00:00:00Z")
      expect(result.length).to eq(1)
      expect(result.first["name"]).to eq("Active App")
    end

    it "excludes apps with empty last_reported_at when filtering by active_since" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"apps": [{"id": 1, "name": "App with date", "last_reported_at": "2025-01-15T00:00:00Z"}, {"id": 2, "name": "App without date", "last_reported_at": ""}, {"id": 3, "name": "App with nil date"}]}}')

      result = client.list_apps(active_since: "2025-01-10T00:00:00Z")
      expect(result.length).to eq(1)
      expect(result.first["name"]).to eq("App with date")
    end

    it "returns empty array when no apps" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.list_apps
      expect(result).to eq([])
    end
  end

  describe "#get_app" do
    it "makes a GET request to /apps/:app_id and returns app hash" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"app": {"id": 123, "name": "Test App"}}}')

      result = client.get_app(app_id)
      expect(result).to eq({"id" => 123, "name" => "Test App"})
    end

    it "returns empty hash when app not found" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.get_app(app_id)
      expect(result).to eq({})
    end
  end

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

  describe "#list_endpoints" do
    it "makes a GET request to /apps/:app_id/endpoints and returns endpoints array" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": [{"id": 1, "name": "/test"}]}')

      result = client.list_endpoints(app_id)
      expect(result).to eq([{"id" => 1, "name" => "/test"}])
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
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
  end

  describe "#get_endpoint" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id and returns endpoint hash" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"endpoint": {"id": 1, "name": "/test"}}}')

      result = client.get_endpoint(app_id, endpoint_id)
      expect(result).to eq({"id" => 1, "name" => "/test"})
    end
  end

  describe "#get_endpoint_metrics" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id/metrics/:metric_type and returns metric array" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      metric_type = "response_time"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
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
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/metrics/#{metric_type}?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"series": {}}}')

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
  end

  describe "#list_endpoint_traces" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id/traces and returns traces array" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/traces")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
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
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"traces": []}}')

      result = client.list_endpoint_traces(app_id, endpoint_id, from: from, to: to)
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

  describe "#list_error_groups" do
    it "makes a GET request to /apps/:app_id/error_groups and returns error groups array" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"error_groups": [{"id": 1}]}}')

      result = client.list_error_groups(app_id)
      expect(result).to eq([{"id" => 1}])
    end

    it "does not include query string when all parameters are nil" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"error_groups": []}}')

      result = client.list_error_groups(app_id, from: nil, to: nil, endpoint: nil)
      expect(result).to eq([])
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      endpoint = "test-endpoint"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}&endpoint=#{CGI.escape(endpoint)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"error_groups": []}}')

      result = client.list_error_groups(app_id, from: from, to: to, endpoint: endpoint)
      expect(result).to eq([])
    end
  end

  describe "#get_error_group" do
    it "makes a GET request to /apps/:app_id/error_groups/:error_id and returns error group hash" do
      app_id = 123
      error_id = 789
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups/#{error_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"error_group": {"id": 789}}}')

      result = client.get_error_group(app_id, error_id)
      expect(result).to eq({"id" => 789})
    end
  end

  describe "#get_error_group_errors" do
    it "makes a GET request to /apps/:app_id/error_groups/:error_id/errors and returns errors array" do
      app_id = 123
      error_id = 789
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups/#{error_id}/errors")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"errors": [{"id": 1}]}}')

      result = client.get_error_group_errors(app_id, error_id)
      expect(result).to eq([{"id" => 1}])
    end
  end

  describe "#get_all_insights" do
    it "makes a GET request to /apps/:app_id/insights and returns insights hash" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"n_plus_one": {"count": 5}}}')

      result = client.get_all_insights(app_id)
      expect(result).to eq({"n_plus_one" => {"count" => 5}})
    end

    it "includes limit parameter when provided" do
      app_id = 123
      limit = 50
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights?limit=#{limit}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.get_all_insights(app_id, limit: limit)
      expect(result).to eq({})
    end
  end

  describe "#get_insight_by_type" do
    it "makes a GET request to /apps/:app_id/insights/:insight_type and returns insights hash" do
      app_id = 123
      insight_type = "n_plus_one"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/#{insight_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"count": 5}}')

      result = client.get_insight_by_type(app_id, insight_type)
      expect(result).to eq({"count" => 5})
    end

    it "includes limit parameter when provided" do
      app_id = 123
      insight_type = "n_plus_one"
      limit = 50
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/#{insight_type}?limit=#{limit}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.get_insight_by_type(app_id, insight_type, limit: limit)
      expect(result).to eq({})
    end

    it "validates insight type" do
      app_id = 123
      expect {
        client.get_insight_by_type(app_id, "invalid_insight")
      }.to raise_error(ArgumentError, /Invalid insight_type/)
    end
  end

  describe "#get_insights_history" do
    it "makes a GET request to /apps/:app_id/insights/history" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history(app_id)
      expect(result).to eq({"results" => []})
    end

    it "does not include query string when all parameters are nil" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history(
        app_id,
        from: nil,
        to: nil,
        limit: nil,
        pagination_cursor: nil,
        pagination_direction: nil,
        pagination_page: nil
      )
      expect(result).to eq({"results" => []})
    end

    it "includes pagination parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      limit = 20
      pagination_cursor = 100
      pagination_direction = "forward"
      pagination_page = 2
      query = "from=#{CGI.escape(from)}&to=#{CGI.escape(to)}&limit=#{limit}&pagination_cursor=#{pagination_cursor}&pagination_direction=#{pagination_direction}&pagination_page=#{pagination_page}"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history?#{query}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history(
        app_id,
        from: from,
        to: to,
        limit: limit,
        pagination_cursor: pagination_cursor,
        pagination_direction: pagination_direction,
        pagination_page: pagination_page
      )
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_insights_history_by_type" do
    it "makes a GET request to /apps/:app_id/insights/history/:insight_type" do
      app_id = 123
      insight_type = "slow_query"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history/#{insight_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history_by_type(app_id, insight_type)
      expect(result).to eq({"results" => []})
    end

    it "does not include query string when all parameters are nil" do
      app_id = 123
      insight_type = "slow_query"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history/#{insight_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history_by_type(
        app_id,
        insight_type,
        from: nil,
        to: nil,
        limit: nil,
        pagination_cursor: nil,
        pagination_direction: nil,
        pagination_page: nil
      )
      expect(result).to eq({"results" => []})
    end

    it "includes pagination parameters when provided" do
      app_id = 123
      insight_type = "slow_query"
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      limit = 20
      pagination_cursor = 100
      pagination_direction = "forward"
      pagination_page = 2
      query = "from=#{CGI.escape(from)}&to=#{CGI.escape(to)}&limit=#{limit}&pagination_cursor=#{pagination_cursor}&pagination_direction=#{pagination_direction}&pagination_page=#{pagination_page}"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history/#{insight_type}?#{query}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history_by_type(
        app_id,
        insight_type,
        from: from,
        to: to,
        limit: limit,
        pagination_cursor: pagination_cursor,
        pagination_direction: pagination_direction,
        pagination_page: pagination_page
      )
      expect(result).to eq({"results" => []})
    end
  end

  describe "#fetch_openapi_schema" do
    it "makes a GET request to the OpenAPI schema endpoint" do
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .with(headers: {"X-SCOUT-API" => api_key, "User-Agent" => "scout-apm-mcp-rb/0.1.3", "Accept" => "application/x-yaml, application/yaml, text/yaml, */*"})
        .to_return(status: 200, body: "openapi: 3.0.0\n", headers: {"Content-Type" => "application/x-yaml"})

      result = client.fetch_openapi_schema
      expect(result[:content]).to eq("openapi: 3.0.0\n")
      expect(result[:content_type]).to eq("application/x-yaml")
      expect(result[:status]).to eq(200)
    end

    it "raises an error on 401 Unauthorized" do
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .to_return(status: 401, body: "Unauthorized")

      expect { client.fetch_openapi_schema }.to raise_error(/Authentication failed/)
    end

    it "raises an error on other HTTP errors" do
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .to_return(status: 500, body: "Internal server error")

      expect { client.fetch_openapi_schema }.to raise_error(/API request failed/)
    end

    it "handles SSL errors with descriptive message" do
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error: certificate verify failed"))

      expect { client.fetch_openapi_schema }.to raise_error(ScoutApmMcp::Error, /SSL verification failed/)
    end

    it "handles generic request errors in fetch_openapi_schema" do
      # Use a different exception type that won't be caught by specific handlers
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .to_raise(Errno::ECONNREFUSED.new("Connection refused"))

      expect { client.fetch_openapi_schema }.to raise_error(ScoutApmMcp::Error, /Request failed/)
    end
  end

  describe "SSL certificate handling" do
    around do |example|
      original_ssl_cert_file = ENV["SSL_CERT_FILE"]
      example.run
      ENV["SSL_CERT_FILE"] = original_ssl_cert_file if original_ssl_cert_file
      ENV.delete("SSL_CERT_FILE") unless original_ssl_cert_file
    end

    it "uses SSL_CERT_FILE environment variable when set and file exists" do
      require "tmpdir"
      cert_file = File.join(Dir.tmpdir, "test_cert.pem")
      File.write(cert_file, "test cert content")
      ENV["SSL_CERT_FILE"] = cert_file

      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"apps": []}}')

      # Verify the request succeeds (cert file is set)
      result = client.list_apps
      expect(result).to eq([])

      File.delete(cert_file) if File.exist?(cert_file)
    end

    it "falls back to default cert file when SSL_CERT_FILE is not set" do
      ENV.delete("SSL_CERT_FILE")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)

      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/0.1.3"})
        .to_return(status: 200, body: '{"results": {"apps": []}}')

      result = client.list_apps
      expect(result).to eq([])
    end
  end

  describe "error handling" do
    it "raises AuthError on 401 Unauthorized" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_return(status: 401, body: '{"error": "Unauthorized"}')

      expect { client.list_apps }.to raise_error(ScoutApmMcp::AuthError, /Authentication failed/)
    end

    it "raises APIError on 404 Not Found" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps/999")
        .to_return(status: 404, body: '{"error": "Not found"}')

      expect { client.get_app(999) }.to raise_error(ScoutApmMcp::APIError, /Resource not found/)
    end

    it "raises APIError on other HTTP errors" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_return(status: 500, body: '{"error": "Internal server error"}')

      expect { client.list_apps }.to raise_error(ScoutApmMcp::APIError)
    end

    it "raises APIError for API-level error codes in response body" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps/999")
        .to_return(status: 200, body: '{"header": {"status": {"code": 404, "message": "App not found"}}}')

      expect { client.get_app(999) }.to raise_error(ScoutApmMcp::APIError, /App not found/)
    end

    it "handles SSL errors with descriptive message" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error: certificate verify failed"))

      expect { client.list_apps }.to raise_error(ScoutApmMcp::Error, /SSL verification failed/)
    end

    it "handles generic request errors" do
      # Use a different exception type that won't be caught by specific handlers
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_raise(Errno::ECONNREFUSED.new("Connection refused"))

      expect { client.list_apps }.to raise_error(ScoutApmMcp::Error, /Request failed/)
    end

    it "handles other non-SSL, non-Error exceptions" do
      # Test the generic rescue clause that catches all other exceptions
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Timeout::Error.new("Request timeout"))

      expect { client.list_apps }.to raise_error(ScoutApmMcp::Error, /Request failed/)
    end

    it "handles invalid JSON response" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_return(status: 200, body: "invalid json{")

      expect { client.list_apps }.to raise_error(ScoutApmMcp::APIError, /Invalid JSON response/)
    end

    it "handles API errors with error message in header.status.message" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps/999")
        .to_return(status: 500, body: '{"header": {"status": {"code": 500, "message": "Custom error message"}}}')

      expect { client.get_app(999) }.to raise_error(ScoutApmMcp::APIError, /Custom error message/)
    end

    it "handles API errors without error message in header" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps/999")
        .to_return(status: 500, body: '{"error": "Some error"}')

      expect { client.get_app(999) }.to raise_error(ScoutApmMcp::APIError, /API request failed/)
    end
  end
end
