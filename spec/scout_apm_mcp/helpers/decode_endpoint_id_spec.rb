require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".decode_endpoint_id" do
    it "decodes URL-safe base64 encoded endpoint ID" do
      endpoint = "Controller/Test/POST/TestController/test_action"
      encoded = Base64.urlsafe_encode64(endpoint)
      decoded = described_class.decode_endpoint_id(encoded)
      expect(decoded).to eq(endpoint)
    end

    it "falls back to standard base64 if URL-safe decoding fails" do
      encoded = Base64.strict_encode64("test-endpoint")
      decoded = described_class.decode_endpoint_id(encoded)
      expect(decoded).to eq("test-endpoint")
    end

    it "returns original string if both decodings fail" do
      invalid = "not-base64-encoded"
      decoded = described_class.decode_endpoint_id(invalid)

      aggregate_failures do
        expect(decoded).to eq(invalid)
        expect(decoded.encoding).to eq(Encoding::UTF_8)
      end
    end

    it "handles exceptions during decoding and returns original string" do
      invalid = "not-base64-encoded"
      allow(Base64).to receive(:urlsafe_decode64).and_raise(StandardError.new("Decode error"))
      allow(Base64).to receive(:decode64).and_raise(StandardError.new("Decode error"))

      decoded = described_class.decode_endpoint_id(invalid)

      aggregate_failures do
        expect(decoded).to eq(invalid)
        expect(decoded.encoding).to eq(Encoding::UTF_8)
      end
    end

    it "falls back to standard base64 when URL-safe decode produces invalid UTF-8" do
      endpoint = "test-endpoint"
      encoded = Base64.strict_encode64(endpoint)
      allow(Base64).to receive(:urlsafe_decode64).with(encoded).and_return("\xFF\xFE".force_encoding(Encoding::BINARY))
      allow(Base64).to receive(:decode64).with(encoded).and_return(endpoint)

      decoded = described_class.decode_endpoint_id(encoded)

      aggregate_failures do
        expect(decoded).to eq(endpoint)
        expect(decoded.encoding).to eq(Encoding::UTF_8)
      end
    end

    it "returns original string when both decodings produce invalid UTF-8" do
      endpoint_id = "test-endpoint-id"
      allow(Base64).to receive(:urlsafe_decode64).with(endpoint_id).and_return("\xFF\xFE".force_encoding(Encoding::BINARY))
      allow(Base64).to receive(:decode64).with(endpoint_id).and_return("\xFF\xFE".force_encoding(Encoding::BINARY))

      decoded = described_class.decode_endpoint_id(endpoint_id)

      aggregate_failures do
        expect(decoded).to eq(endpoint_id)
        expect(decoded.encoding).to eq(Encoding::UTF_8)
      end
    end
  end
end
