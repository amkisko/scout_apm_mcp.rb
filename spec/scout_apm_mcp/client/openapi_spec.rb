require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#fetch_openapi_schema" do
    it "makes a GET request to the OpenAPI schema endpoint" do
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .with(headers: {"X-SCOUT-API" => api_key, "User-Agent" => "scout-apm-mcp-rb/#{ScoutApmMcp::VERSION}", "Accept" => "application/x-yaml, application/yaml, text/yaml, */*"})
        .to_return(status: 200, body: "openapi: 3.0.0\n", headers: {"Content-Type" => "application/x-yaml"})

      result = client.fetch_openapi_schema

      aggregate_failures do
        expect(result[:content]).to eq("openapi: 3.0.0\n")
        expect(result[:content_type]).to eq("application/x-yaml")
        expect(result[:status]).to eq(200)
      end
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
      stub_request(:get, "https://scoutapm.com/api/v0/openapi.yaml")
        .to_raise(Errno::ECONNREFUSED.new("Connection refused"))

      expect { client.fetch_openapi_schema }.to raise_error(ScoutApmMcp::Error, /Request failed/)
    end
  end
end
