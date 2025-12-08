require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".parse_scout_url" do
    it "parses a ScoutAPM trace URL correctly" do
      endpoint_id = Base64.urlsafe_encode64("Controller/Test/POST/TestController/test_action")
      url = "https://scoutapm.com/apps/123/endpoints/#{endpoint_id}/trace/456"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:trace)
        expect(result[:endpoint_id]).to eq(endpoint_id)
        expect(result[:trace_id]).to eq(456)
        expect(result[:decoded_endpoint]).to eq("Controller/Test/POST/TestController/test_action")
      end
    end

    it "parses query parameters" do
      url = "https://scoutapm.com/apps/123/endpoints/abc/trace/456?foo=bar&baz=qux"
      result = described_class.parse_scout_url(url)

      expect(result[:query_params]).to eq({"foo" => "bar", "baz" => "qux"})
    end

    it "handles URLs without query parameters" do
      url = "https://scoutapm.com/apps/123/endpoints/abc/trace/456"
      result = described_class.parse_scout_url(url)

      expect(result[:query_params]).to be_nil
    end

    it "handles malformed URLs gracefully" do
      url = "https://scoutapm.com/invalid/path"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to be_nil
        expect(result[:endpoint_id]).to be_nil
        expect(result[:trace_id]).to be_nil
      end
    end

    it "parses a ScoutAPM endpoint URL correctly" do
      endpoint_id = Base64.urlsafe_encode64("Controller/Test/POST/TestController/test_action")
      url = "https://scoutapm.com/apps/123/endpoints/#{endpoint_id}"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:endpoint)
        expect(result[:endpoint_id]).to eq(endpoint_id)
        expect(result[:decoded_endpoint]).to eq("Controller/Test/POST/TestController/test_action")
      end
    end

    it "parses a ScoutAPM error group URL correctly" do
      url = "https://scoutapm.com/apps/123/error_groups/789"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:error_group)
        expect(result[:error_id]).to eq(789)
      end
    end

    it "parses a ScoutAPM insights URL correctly" do
      url = "https://scoutapm.com/apps/123/insights"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:insight)
        expect(result[:insight_type]).to be_nil
      end
    end

    it "parses a ScoutAPM insights URL with type correctly" do
      url = "https://scoutapm.com/apps/123/insights/n_plus_one"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:insight)
        expect(result[:insight_type]).to eq("n_plus_one")
      end
    end

    it "parses a ScoutAPM app URL correctly" do
      url = "https://scoutapm.com/apps/123"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:app)
      end
    end

    it "parses unknown URL types correctly" do
      url = "https://scoutapm.com/apps/123/unknown/path"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to eq(123)
        expect(result[:url_type]).to eq(:unknown)
      end
    end

    it "handles URLs without apps in path" do
      url = "https://scoutapm.com/some/other/path"
      result = described_class.parse_scout_url(url)

      aggregate_failures do
        expect(result[:app_id]).to be_nil
        expect(result[:url_type]).to be_nil
      end
    end
  end
end
