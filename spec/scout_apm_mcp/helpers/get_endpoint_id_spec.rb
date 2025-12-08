require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".get_endpoint_id" do
    it "extracts endpoint ID from endpoint hash with string key" do
      endpoint = {"link" => "https://scoutapm.com/apps/123/endpoints/abc123"}
      result = described_class.get_endpoint_id(endpoint)
      expect(result).to eq("abc123")
    end

    it "extracts endpoint ID from endpoint hash with symbol key" do
      endpoint = {link: "https://scoutapm.com/apps/123/endpoints/xyz789"}
      result = described_class.get_endpoint_id(endpoint)
      expect(result).to eq("xyz789")
    end

    it "returns empty string when link is missing" do
      endpoint = {"name" => "test"}
      result = described_class.get_endpoint_id(endpoint)
      expect(result).to eq("")
    end

    it "returns empty string when link is empty" do
      endpoint = {"link" => ""}
      result = described_class.get_endpoint_id(endpoint)
      expect(result).to eq("")
    end

    it "handles link with trailing slash" do
      endpoint = {"link" => "https://scoutapm.com/apps/123/endpoints/abc123/"}
      result = described_class.get_endpoint_id(endpoint)
      expect(result).to eq("abc123")
    end
  end
end
