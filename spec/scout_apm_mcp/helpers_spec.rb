require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".get_api_key" do
    context "when api_key is provided directly" do
      it "returns the provided API key" do
        api_key = "direct-api-key"
        result = described_class.get_api_key(api_key: api_key)
        expect(result).to eq(api_key)
      end
    end

    context "when api_key is an empty string" do
      around do |example|
        original = ENV["API_KEY"]
        ENV["API_KEY"] = "env-api-key"
        example.run
        ENV["API_KEY"] = original
      end

      it "ignores empty string and falls back to environment" do
        result = described_class.get_api_key(api_key: "")
        expect(result).to eq("env-api-key")
      end
    end

    context "when API_KEY environment variable is set" do
      around do |example|
        original = ENV["API_KEY"]
        ENV["API_KEY"] = "env-api-key"
        example.run
        ENV["API_KEY"] = original
      end

      it "returns the API key from environment" do
        result = described_class.get_api_key
        expect(result).to eq("env-api-key")
      end
    end

    context "when SCOUT_APM_API_KEY environment variable is set" do
      around do |example|
        original = ENV["SCOUT_APM_API_KEY"]
        ENV["SCOUT_APM_API_KEY"] = "scout-env-api-key"
        example.run
        ENV["SCOUT_APM_API_KEY"] = original
      end

      it "returns the API key from environment" do
        result = described_class.get_api_key
        expect(result).to eq("scout-env-api-key")
      end
    end

    context "when OP_ENV_ENTRY_PATH environment variable is set" do
      around do |example|
        original_api_key = ENV["API_KEY"]
        original_scout_key = ENV["SCOUT_APM_API_KEY"]
        original_op_env = ENV["OP_ENV_ENTRY_PATH"]
        ENV.delete("API_KEY")
        ENV.delete("SCOUT_APM_API_KEY")
        ENV["OP_ENV_ENTRY_PATH"] = "op://TestVault/TestItem"
        example.run
        ENV["API_KEY"] = original_api_key if original_api_key
        ENV["SCOUT_APM_API_KEY"] = original_scout_key if original_scout_key
        ENV["OP_ENV_ENTRY_PATH"] = original_op_env if original_op_env
      end

      it "loads API key from 1Password via opdotenv using OP_ENV_ENTRY_PATH" do
        opdotenv_loader = double("Opdotenv::Loader")
        allow(described_class).to receive(:require).with("opdotenv").and_return(true)
        stub_const("Opdotenv::Loader", opdotenv_loader)
        allow(opdotenv_loader).to receive(:load).with("op://TestVault/TestItem").and_return(true)
        ENV["API_KEY"] = "op-env-entry-path-key"

        result = described_class.get_api_key
        expect(result).to eq("op-env-entry-path-key")
      end

      it "falls back to op CLI if opdotenv is not available" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).with(/op read "op:\/\/TestVault\/TestItem\/API_KEY"/).and_return("op-cli-key\n")

        result = described_class.get_api_key
        expect(result).to eq("op-cli-key")
      end

      it "falls back to environment variable if OP_ENV_ENTRY_PATH and op CLI both fail" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).and_return("\n")
        ENV["API_KEY"] = "fallback-key"

        result = described_class.get_api_key
        expect(result).to eq("fallback-key")
      end
    end

    context "when 1Password opdotenv integration is available" do
      around do |example|
        original_api_key = ENV["API_KEY"]
        original_scout_key = ENV["SCOUT_APM_API_KEY"]
        original_op_env = ENV["OP_ENV_ENTRY_PATH"]
        ENV.delete("API_KEY")
        ENV.delete("SCOUT_APM_API_KEY")
        ENV.delete("OP_ENV_ENTRY_PATH")
        example.run
        ENV["API_KEY"] = original_api_key if original_api_key
        ENV["SCOUT_APM_API_KEY"] = original_scout_key if original_scout_key
        ENV["OP_ENV_ENTRY_PATH"] = original_op_env if original_op_env
      end

      it "loads API key from 1Password via opdotenv" do
        opdotenv_loader = double("Opdotenv::Loader")
        allow(described_class).to receive(:require).with("opdotenv").and_return(true)
        stub_const("Opdotenv::Loader", opdotenv_loader)
        allow(opdotenv_loader).to receive(:load).and_return(true)
        ENV["API_KEY"] = "opdotenv-api-key"

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem")
        expect(result).to eq("opdotenv-api-key")
      end

      it "handles empty string from opdotenv" do
        opdotenv_loader = double("Opdotenv::Loader")
        allow(described_class).to receive(:require).with("opdotenv").and_return(true)
        stub_const("Opdotenv::Loader", opdotenv_loader)
        allow(opdotenv_loader).to receive(:load).and_return(true)
        ENV["API_KEY"] = ""
        allow(described_class).to receive(:`).with(/op read/).and_return("op-cli-key\n")

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem")
        expect(result).to eq("op-cli-key")
      end

      it "loads API key from SCOUT_APM_API_KEY after opdotenv" do
        opdotenv_loader = double("Opdotenv::Loader")
        allow(described_class).to receive(:require).with("opdotenv").and_return(true)
        stub_const("Opdotenv::Loader", opdotenv_loader)
        allow(opdotenv_loader).to receive(:load).and_return(true)
        ENV.delete("API_KEY")
        ENV["SCOUT_APM_API_KEY"] = "scout-opdotenv-key"

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem")
        expect(result).to eq("scout-opdotenv-key")
      end

      it "handles opdotenv LoadError gracefully" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).with(/op read/).and_return("op-cli-key\n")

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem")
        expect(result).to eq("op-cli-key")
      end

      it "handles opdotenv errors gracefully" do
        opdotenv_loader = double("Opdotenv::Loader")
        allow(described_class).to receive(:require).with("opdotenv").and_return(true)
        stub_const("Opdotenv::Loader", opdotenv_loader)
        allow(opdotenv_loader).to receive(:load).and_raise(StandardError.new("opdotenv error"))
        allow(described_class).to receive(:`).with(/op read/).and_return("op-cli-key\n")

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem")
        expect(result).to eq("op-cli-key")
      end
    end

    context "when 1Password CLI integration is used" do
      around do |example|
        original_api_key = ENV["API_KEY"]
        original_scout_key = ENV["SCOUT_APM_API_KEY"]
        ENV.delete("API_KEY")
        ENV.delete("SCOUT_APM_API_KEY")
        example.run
        ENV["API_KEY"] = original_api_key if original_api_key
        ENV["SCOUT_APM_API_KEY"] = original_scout_key if original_scout_key
      end

      it "loads API key from 1Password CLI" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).with(/op read "op:\/\/TestVault\/TestItem\/API_KEY"/).and_return("op-cli-key\n")

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem")
        expect(result).to eq("op-cli-key")
      end

      it "handles empty string from 1Password CLI" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).with(/op read/).and_return("\n")

        expect { described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem") }
          .to raise_error(/API_KEY not found/)
      end

      it "handles 1Password CLI errors gracefully" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).and_raise(StandardError.new("op CLI error"))

        expect { described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem") }
          .to raise_error(/API_KEY not found/)
      end

      it "uses custom op_field parameter" do
        allow(described_class).to receive(:require).with("opdotenv").and_raise(LoadError)
        allow(described_class).to receive(:`).with(/op read "op:\/\/TestVault\/TestItem\/CUSTOM_FIELD"/).and_return("custom-field-key\n")

        result = described_class.get_api_key(op_vault: "TestVault", op_item: "TestItem", op_field: "CUSTOM_FIELD")
        expect(result).to eq("custom-field-key")
      end
    end

    context "when no API key is found" do
      around do |example|
        original_api_key = ENV["API_KEY"]
        original_scout_key = ENV["SCOUT_APM_API_KEY"]
        ENV.delete("API_KEY")
        ENV.delete("SCOUT_APM_API_KEY")
        example.run
        ENV["API_KEY"] = original_api_key if original_api_key
        ENV["SCOUT_APM_API_KEY"] = original_scout_key if original_scout_key
      end

      it "raises an error" do
        allow(described_class).to receive(:`).and_return("")
        expect { described_class.get_api_key }.to raise_error(/API_KEY not found/)
      end
    end
  end

  describe ".parse_scout_url" do
    it "parses a ScoutAPM trace URL correctly" do
      # Use a generic endpoint ID for testing
      endpoint_id = Base64.urlsafe_encode64("Controller/Test/POST/TestController/test_action")
      url = "https://scoutapm.com/apps/123/endpoints/#{endpoint_id}/trace/456"
      result = described_class.parse_scout_url(url)

      expect(result[:app_id]).to eq(123)
      expect(result[:endpoint_id]).to eq(endpoint_id)
      expect(result[:trace_id]).to eq(456)
      expect(result[:decoded_endpoint]).to eq("Controller/Test/POST/TestController/test_action")
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

      expect(result[:app_id]).to be_nil
      expect(result[:endpoint_id]).to be_nil
      expect(result[:trace_id]).to be_nil
    end

    it "uses fallback path extraction when indices are not found" do
      url = "https://scoutapm.com/apps/123/endpoints/abc/trace/456"
      result = described_class.parse_scout_url(url)

      expect(result[:app_id]).to eq(123)
      expect(result[:endpoint_id]).to eq("abc")
      expect(result[:trace_id]).to eq(456)
    end
  end

  describe ".decode_endpoint_id" do
    it "decodes URL-safe base64 encoded endpoint ID" do
      endpoint = "Controller/Test/POST/TestController/test_action"
      encoded = Base64.urlsafe_encode64(endpoint)
      decoded = described_class.decode_endpoint_id(encoded)
      expect(decoded).to eq(endpoint)
    end

    it "falls back to standard base64 if URL-safe decoding fails" do
      # Standard base64 encoding (not URL-safe) - this should fail URL-safe decode
      # but succeed with standard decode
      encoded = Base64.strict_encode64("test-endpoint")
      # Standard base64 with + and / characters (not URL-safe)
      # This will decode correctly with standard Base64.decode64
      decoded = described_class.decode_endpoint_id(encoded)
      expect(decoded).to eq("test-endpoint")
    end

    it "returns original string if both decodings fail" do
      invalid = "not-base64-encoded"
      decoded = described_class.decode_endpoint_id(invalid)
      expect(decoded).to eq(invalid)
      expect(decoded.encoding).to eq(Encoding::UTF_8)
    end

    it "handles exceptions during decoding and returns original string" do
      invalid = "not-base64-encoded"
      # Force an exception by stubbing Base64 methods to raise
      allow(Base64).to receive(:urlsafe_decode64).and_raise(StandardError.new("Decode error"))
      allow(Base64).to receive(:decode64).and_raise(StandardError.new("Decode error"))

      decoded = described_class.decode_endpoint_id(invalid)
      expect(decoded).to eq(invalid)
      expect(decoded.encoding).to eq(Encoding::UTF_8)
    end
  end
end
