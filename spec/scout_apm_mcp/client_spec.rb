require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
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
    it "makes a GET request to /apps" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_apps
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_app" do
    it "makes a GET request to /apps/:app_id" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": {"id": 123}}')

      result = client.get_app(app_id)
      expect(result).to eq({"results" => {"id" => 123}})
    end
  end

  describe "#list_metrics" do
    it "makes a GET request to /apps/:app_id/metrics" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_metrics(app_id)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_metric" do
    it "makes a GET request to /apps/:app_id/metrics/:metric_type" do
      app_id = 123
      metric_type = "response_time"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_metric(app_id, metric_type)
      expect(result).to eq({"results" => []})
    end

    it "includes query parameters when provided" do
      app_id = 123
      metric_type = "response_time"
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics/#{metric_type}?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_metric(app_id, metric_type, from: from, to: to)
      expect(result).to eq({"results" => []})
    end

    it "does not include query string when parameters are nil" do
      app_id = 123
      metric_type = "response_time"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_metric(app_id, metric_type, from: nil, to: nil)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#list_endpoints" do
    it "makes a GET request to /apps/:app_id/endpoints" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_endpoints(app_id)
      expect(result).to eq({"results" => []})
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_endpoints(app_id, from: from, to: to)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_endpoint" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.get_endpoint(app_id, endpoint_id)
      expect(result).to eq({"results" => {}})
    end
  end

  describe "#get_endpoint_metrics" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id/metrics/:metric_type" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      metric_type = "response_time"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_endpoint_metrics(app_id, endpoint_id, metric_type)
      expect(result).to eq({"results" => []})
    end

    it "includes query parameters when provided" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      metric_type = "response_time"
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/metrics/#{metric_type}?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_endpoint_metrics(app_id, endpoint_id, metric_type, from: from, to: to)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#list_endpoint_traces" do
    it "makes a GET request to /apps/:app_id/endpoints/:endpoint_id/traces" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/traces")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_endpoint_traces(app_id, endpoint_id)
      expect(result).to eq({"results" => []})
    end

    it "includes query parameters when provided" do
      app_id = 123
      endpoint_id = "test-endpoint-id"
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      encoded_id = CGI.escape(endpoint_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/endpoints/#{encoded_id}/traces?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_endpoint_traces(app_id, endpoint_id, from: from, to: to)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#fetch_trace" do
    it "makes a GET request to /apps/:app_id/traces/:trace_id" do
      app_id = 123
      trace_id = 456
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/traces/#{trace_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": {"trace": {}}}')

      result = client.fetch_trace(app_id, trace_id)
      expect(result).to eq({"results" => {"trace" => {}}})
    end
  end

  describe "#list_error_groups" do
    it "makes a GET request to /apps/:app_id/error_groups" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_error_groups(app_id)
      expect(result).to eq({"results" => []})
    end

    it "does not include query string when all parameters are nil" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_error_groups(app_id, from: nil, to: nil, endpoint: nil)
      expect(result).to eq({"results" => []})
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      endpoint = "test-endpoint"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}&endpoint=#{CGI.escape(endpoint)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_error_groups(app_id, from: from, to: to, endpoint: endpoint)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_error_group" do
    it "makes a GET request to /apps/:app_id/error_groups/:error_id" do
      app_id = 123
      error_id = 789
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups/#{error_id}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": {}}')

      result = client.get_error_group(app_id, error_id)
      expect(result).to eq({"results" => {}})
    end
  end

  describe "#get_error_group_errors" do
    it "makes a GET request to /apps/:app_id/error_groups/:error_id/errors" do
      app_id = 123
      error_id = 789
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/error_groups/#{error_id}/errors")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_error_group_errors(app_id, error_id)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_all_insights" do
    it "makes a GET request to /apps/:app_id/insights" do
      app_id = 123
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_all_insights(app_id)
      expect(result).to eq({"results" => []})
    end

    it "includes limit parameter when provided" do
      app_id = 123
      limit = 50
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights?limit=#{limit}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_all_insights(app_id, limit: limit)
      expect(result).to eq({"results" => []})
    end
  end

  describe "#get_insight_by_type" do
    it "makes a GET request to /apps/:app_id/insights/:insight_type" do
      app_id = 123
      insight_type = "n_plus_one"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/#{insight_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insight_by_type(app_id, insight_type)
      expect(result).to eq({"results" => []})
    end

    it "includes limit parameter when provided" do
      app_id = 123
      insight_type = "n_plus_one"
      limit = 50
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/insights/#{insight_type}?limit=#{limit}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json"})
        .to_return(status: 200, body: '{"results": []}')

      result = client.get_insight_by_type(app_id, insight_type, limit: limit)
      expect(result).to eq({"results" => []})
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
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/x-yaml, application/yaml, text/yaml, */*"})
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

      expect { client.fetch_openapi_schema }.to raise_error(/SSL verification failed/)
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
        .to_return(status: 200, body: '{"results": []}')

      # Verify the request succeeds (cert file is set)
      result = client.list_apps
      expect(result).to eq({"results" => []})

      File.delete(cert_file) if File.exist?(cert_file)
    end

    it "falls back to default cert file when SSL_CERT_FILE is not set" do
      ENV.delete("SSL_CERT_FILE")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(OpenSSL::X509::DEFAULT_CERT_FILE).and_return(true)

      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_return(status: 200, body: '{"results": []}')

      result = client.list_apps
      expect(result).to eq({"results" => []})
    end
  end

  describe "error handling" do
    it "raises an error on 401 Unauthorized" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_return(status: 401, body: '{"error": "Unauthorized"}')

      expect { client.list_apps }.to raise_error(/Authentication failed/)
    end

    it "raises an error on 404 Not Found" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps/999")
        .to_return(status: 404, body: '{"error": "Not found"}')

      expect { client.get_app(999) }.to raise_error(/Resource not found/)
    end

    it "raises an error on other HTTP errors" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_return(status: 500, body: '{"error": "Internal server error"}')

      expect { client.list_apps }.to raise_error(/API request failed/)
    end

    it "handles SSL errors with descriptive message" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error: certificate verify failed"))

      expect { client.list_apps }.to raise_error(/SSL verification failed/)
    end

    it "handles generic request errors" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_raise(StandardError.new("Network error"))

      expect { client.list_apps }.to raise_error(/Request failed/)
    end
  end
end
