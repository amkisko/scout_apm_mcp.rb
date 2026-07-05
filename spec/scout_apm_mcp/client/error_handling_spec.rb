require "spec_helper"
require "cgi"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "error handling" do
    before do
      allow(client).to receive(:sleep)
    end

    describe "request retries" do
      let(:request_uri) { URI("https://scoutapm.com/api/v0/apps") }

      it "retries retryable API errors before succeeding" do
        attempts = 0
        allow(client).to receive(:perform_request).with(request_uri) do
          attempts += 1
          raise ScoutApmMcp::APIError.new("Unavailable", status_code: 503) if attempts == 1

          {"results" => {"apps" => [{"id" => 1}]}}
        end

        expect(client.send(:make_request, request_uri)).to eq({"results" => {"apps" => [{"id" => 1}]}})
        expect(attempts).to eq(2)
        expect(client).to have_received(:sleep).once
      end

      it "retries timeout errors before succeeding" do
        attempts = 0
        allow(client).to receive(:perform_request).with(request_uri) do
          attempts += 1
          raise Timeout::Error, "execution expired" if attempts == 1

          {"results" => {"apps" => []}}
        end

        expect(client.send(:make_request, request_uri)).to eq({"results" => {"apps" => []}})
        expect(attempts).to eq(2)
        expect(client).to have_received(:sleep).once
      end

      it "does not retry authentication failures" do
        allow(client).to receive(:perform_request).and_raise(ScoutApmMcp::AuthError.new("Authentication failed"))

        expect { client.send(:make_request, request_uri) }.to raise_error(ScoutApmMcp::AuthError)
        expect(client).not_to have_received(:sleep)
      end
    end

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

    it "gives up after the retry limit for connection errors" do
      allow(client).to receive(:perform_request).and_raise(Errno::ECONNREFUSED.new("Connection refused"))

      expect { client.list_apps }.to raise_error(ScoutApmMcp::Error, /Request failed/)
      expect(client).to have_received(:sleep).twice
    end

    it "gives up after the retry limit for timeouts" do
      allow(client).to receive(:perform_request).and_raise(Timeout::Error.new("Request timeout"))

      expect { client.list_apps }.to raise_error(ScoutApmMcp::Error, /Request failed/)
      expect(client).to have_received(:sleep).twice
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
