require "spec_helper"
require "cgi"
require "uri"

RSpec.describe ScoutApmMcp::Client do
  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#list_jobs" do
    it "makes a GET request to /apps/:app_id/jobs and returns jobs array" do
      app_id = 123
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/jobs/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": [{"name": "MyWorker", "job_id": "abc"}]}')

      result = client.list_jobs(app_id)
      expect(result).to eq([{"name" => "MyWorker", "job_id" => "abc"}])
    end

    it "includes query parameters when provided" do
      app_id = 123
      from = "2025-01-01T00:00:00Z"
      to = "2025-01-02T00:00:00Z"
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/jobs?from=#{CGI.escape(from)}&to=#{CGI.escape(to)}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": []}')

      expect(client.list_jobs(app_id, from: from, to: to)).to eq([])
    end

    it "validates time range" do
      app_id = 123
      from = "2025-01-02T00:00:00Z"
      to = "2025-01-01T00:00:00Z"
      expect {
        client.list_jobs(app_id, from: from, to: to)
      }.to raise_error(ArgumentError, /from_time must be before to_time/)
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      to_time = "2025-01-15T12:00:00Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/jobs/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": []}')

      expect(client.list_jobs(app_id, range: "1day", to: to_time)).to eq([])
    end

    it "derives from as 7 days before a provided to when from is omitted" do
      app_id = 456
      to_time = "2025-06-01T15:00:00Z"
      calculated_from = ScoutApmMcp::Helpers.calculate_range(range: "7days", to: to_time)[:from]
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/jobs?from=#{CGI.escape(calculated_from)}&to=#{CGI.escape(to_time)}")
        .to_return(status: 200, body: '{"results": []}')

      expect(client.list_jobs(app_id, to: to_time)).to eq([])
    end

    it "defaults to to: now when only from is provided" do
      app_id = 789
      from = (Time.now.utc - 3600).strftime("%Y-%m-%dT%H:%M:%SZ")
      to_rx = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/jobs\?from=.*&to=.*$/).with { |req|
        q = URI.decode_www_form(URI(req.uri).query.to_s).to_h
        q["from"] == from && q["to"].to_s.match?(to_rx)
      }.to_return(status: 200, body: '{"results": []}')

      expect(client.list_jobs(app_id, from: from)).to eq([])
    end
  end

  describe "#list_job_metrics" do
    it "makes a GET request to /jobs/:job_id/metrics and returns available metrics" do
      app_id = 123
      job_id = "job-encoded-id"
      encoded = CGI.escape(job_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/jobs/#{encoded}/metrics")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"availableMetrics": ["throughput", "latency"]}}')

      expect(client.list_job_metrics(app_id, job_id)).to eq(%w[throughput latency])
    end
  end

  describe "#get_job_metrics" do
    it "makes a GET request and returns series for the metric type" do
      app_id = 123
      job_id = "job-id"
      metric_type = "execution_time"
      encoded = CGI.escape(job_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/jobs/#{encoded}/metrics/#{metric_type}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"series": {"execution_time": [{"timestamp": "2025-01-01T00:00:00Z", "value": 42}]}}}')

      result = client.get_job_metrics(app_id, job_id, metric_type)
      expect(result).to eq([{"timestamp" => "2025-01-01T00:00:00Z", "value" => 42}])
    end

    it "validates job metric type" do
      expect {
        client.get_job_metrics(123, "j", "response_time")
      }.to raise_error(ArgumentError, /Invalid metric_type/)
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      job_id = "jid"
      metric_type = "throughput"
      to_time = "2025-01-15T12:00:00Z"
      stub_request(:get, /https:\/\/scoutapm\.com\/api\/v0\/apps\/#{app_id}\/jobs\/#{job_id}\/metrics\/#{metric_type}/)
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"series": {"throughput": []}}}')

      expect(client.get_job_metrics(app_id, job_id, metric_type, range: "6hrs", to: to_time)).to eq([])
    end
  end

  describe "#list_job_traces" do
    it "makes a GET request to /jobs/:job_id/traces and returns traces" do
      app_id = 123
      job_id = "job-id"
      encoded = CGI.escape(job_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/jobs/#{encoded}/traces")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"traces": [{"id": 99}]}}')

      expect(client.list_job_traces(app_id, job_id)).to eq([{"id" => 99}])
    end

    it "uses range parameter to calculate from/to" do
      app_id = 123
      job_id = "job-id"
      to_time = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      calculated = ScoutApmMcp::Helpers.calculate_range(range: "12hrs", to: to_time)
      encoded = CGI.escape(job_id)
      stub_request(:get, "https://scoutapm.com/api/v0/apps/#{app_id}/jobs/#{encoded}/traces?from=#{CGI.escape(calculated[:from])}&to=#{CGI.escape(calculated[:to])}")
        .with(headers: {"X-SCOUT-API" => api_key, "Accept" => "application/json", "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}"})
        .to_return(status: 200, body: '{"results": {"traces": []}}')

      expect(client.list_job_traces(app_id, job_id, range: "12hrs", to: to_time)).to eq([])
    end

    it "validates that from_time is not older than 7 days" do
      from = (Time.now.utc - (8 * 24 * 60 * 60)).strftime("%Y-%m-%dT%H:%M:%SZ")
      to = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      expect {
        client.list_job_traces(123, "j", from: from, to: to)
      }.to raise_error(ArgumentError, /from_time cannot be older than 7 days/)
    end
  end
end
