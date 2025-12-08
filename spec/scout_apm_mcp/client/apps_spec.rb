require "spec_helper"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#list_apps" do
    it "makes a GET request to /apps and returns apps array" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"apps": [{"id": 1, "name": "Test App"}]}}')

      result = client.list_apps
      expect(result).to eq([{"id" => 1, "name" => "Test App"}])
    end

    it "filters apps by active_since" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"apps": [{"id": 1, "name": "Active App", "last_reported_at": "2025-01-15T00:00:00Z"}, {"id": 2, "name": "Inactive App", "last_reported_at": "2025-01-01T00:00:00Z"}]}}')

      result = client.list_apps(active_since: "2025-01-10T00:00:00Z")

      aggregate_failures do
        expect(result.length).to eq(1)
        expect(result.first["name"]).to eq("Active App")
      end
    end

    it "excludes apps with empty last_reported_at when filtering by active_since" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"apps": [{"id": 1, "name": "App with date", "last_reported_at": "2025-01-15T00:00:00Z"}, {"id": 2, "name": "App without date", "last_reported_at": ""}, {"id": 3, "name": "App with nil date"}]}}')

      result = client.list_apps(active_since: "2025-01-10T00:00:00Z")

      aggregate_failures do
        expect(result.length).to eq(1)
        expect(result.first["name"]).to eq("App with date")
      end
    end

    it "returns empty array when no apps" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.list_apps
      expect(result).to eq([])
    end
  end

  describe "#get_app" do
    it "makes a GET request to /apps/:app_id and returns app hash" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"app": {"id": 123, "name": "Test App"}}}')

      result = client.get_app(app_id)
      expect(result).to eq({"id" => 123, "name" => "Test App"})
    end

    it "returns empty hash when app not found" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.get_app(app_id)
      expect(result).to eq({})
    end
  end
end
