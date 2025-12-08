require "spec_helper"

RSpec.describe ScoutApmMcp::Client do
  include ScoutApmMcp

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

    it "raises ArgumentError when api_key is nil" do
      expect {
        described_class.new(api_key: nil)
      }.to raise_error(ArgumentError, /API key is required/)
    end

    it "raises ArgumentError when api_key is empty string" do
      expect {
        described_class.new(api_key: "")
      }.to raise_error(ArgumentError, /API key is required/)
    end

    it "raises ArgumentError when api_key is whitespace only" do
      expect {
        described_class.new(api_key: "   ")
      }.to raise_error(ArgumentError, /API key is required/)
    end

    it "converts non-string api_key to string" do
      client = described_class.new(api_key: 12345)
      expect(client.instance_variable_get(:@api_key)).to eq("12345")
    end
  end
end
