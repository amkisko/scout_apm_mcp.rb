require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

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
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .to_raise(Errno::ECONNREFUSED.new("Connection refused"))

      expect { client.list_apps }.to raise_error(ScoutApmMcp::Error, /Request failed/)
    end

    it "handles other non-SSL, non-Error exceptions" do
      http_client = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_client)
      allow(http_client).to receive(:read_timeout=)
      allow(http_client).to receive(:open_timeout=)
      allow(http_client).to receive(:use_ssl=)
      allow(http_client).to receive(:verify_mode=)
      allow(http_client).to receive(:ca_file=)
      allow(http_client).to receive(:request).and_raise(Timeout::Error.new("Request timeout"))

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
