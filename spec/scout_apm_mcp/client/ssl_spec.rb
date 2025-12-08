require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

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
end
