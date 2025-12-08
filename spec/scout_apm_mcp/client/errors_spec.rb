require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

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
end
