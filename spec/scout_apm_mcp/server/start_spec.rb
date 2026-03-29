require "spec_helper"
require "scout_apm_mcp/server"

RSpec.describe ScoutApmMcp::Server do
  describe ".start" do
    let(:fake_server) { instance_double(FastMcp::Server) }

    before do
      allow(FastMcp::Server).to receive(:new).and_return(fake_server)
      allow(fake_server).to receive(:start)
      allow(described_class).to receive(:register_tools)
    end

    it "builds an MCP server, registers tools, and starts" do
      described_class.start
      aggregate_failures do
        expect(FastMcp::Server).to have_received(:new).with(
          hash_including(name: "scout-apm", version: ScoutApmMcp::VERSION, logger: kind_of(described_class::NullLogger))
        )
        expect(described_class).to have_received(:register_tools).with(fake_server)
        expect(fake_server).to have_received(:start)
      end
    end

    it "rescues LoadError when OP_ENV_ENTRY_PATH is set but opdotenv is missing" do
      orig = ENV.fetch("OP_ENV_ENTRY_PATH", nil)
      ENV["OP_ENV_ENTRY_PATH"] = "op://vault/item"
      allow(Kernel).to receive(:require).and_call_original
      allow(Kernel).to receive(:require).with("opdotenv").and_raise(LoadError, "no such gem")

      begin
        described_class.start
        expect(fake_server).to have_received(:start)
      ensure
        orig ? ENV["OP_ENV_ENTRY_PATH"] = orig : ENV.delete("OP_ENV_ENTRY_PATH")
      end
    end

    it "rescues generic errors from Opdotenv::Loader.load" do
      orig = ENV.fetch("OP_ENV_ENTRY_PATH", nil)
      ENV["OP_ENV_ENTRY_PATH"] = "op://vault/item"
      stub_const("Opdotenv", Module.new)
      loader_class = Class.new do
        def self.load(*)
          raise StandardError, "vault offline"
        end
      end
      stub_const("Opdotenv::Loader", loader_class)
      allow(Kernel).to receive(:require).and_call_original
      allow(Kernel).to receive(:require).with("opdotenv").and_return(true)

      begin
        described_class.start
        expect(fake_server).to have_received(:start)
      ensure
        orig ? ENV["OP_ENV_ENTRY_PATH"] = orig : ENV.delete("OP_ENV_ENTRY_PATH")
      end
    end
  end
end
