require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

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

      params = {from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil}
      result = client.get_insights_history(app_id, **params)
      expect(result).to eq({"results" => []})
    end

    it "includes pagination parameters when provided" do
      app_id = 123
      params = {from: "2025-01-01T00:00:00Z", to: "2025-01-02T00:00:00Z", limit: 20, pagination_cursor: 100, pagination_direction: "forward", pagination_page: 2}
      query = "from=#{CGI.escape(params[:from])}&to=#{CGI.escape(params[:to])}&limit=#{params[:limit]}&pagination_cursor=#{params[:pagination_cursor]}&pagination_direction=#{params[:pagination_direction]}&pagination_page=#{params[:pagination_page]}"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history?#{query}").with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"}).to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history(app_id, **params)
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

      params = {from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil}
      result = client.get_insights_history_by_type(app_id, insight_type, **params)
      expect(result).to eq({"results" => []})
    end

    it "includes pagination parameters when provided" do
      app_id = 123
      insight_type = "slow_query"
      params = {from: "2025-01-01T00:00:00Z", to: "2025-01-02T00:00:00Z", limit: 20, pagination_cursor: 100, pagination_direction: "forward", pagination_page: 2}
      query = "from=#{CGI.escape(params[:from])}&to=#{CGI.escape(params[:to])}&limit=#{params[:limit]}&pagination_cursor=#{params[:pagination_cursor]}&pagination_direction=#{params[:pagination_direction]}&pagination_page=#{params[:pagination_page]}"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/history/#{insight_type}?#{query}").with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"}).to_return(status: 200, body: '{"results": []}')

      result = client.get_insights_history_by_type(app_id, insight_type, **params)
      expect(result).to eq({"results" => []})
    end
  end
end
