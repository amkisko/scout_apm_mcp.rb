require "spec_helper"
require "scout_apm_mcp/server"

RSpec.describe ScoutApmMcp::Server::NullLogger do
  subject(:logger) { described_class.new }

  it "supports the fast-mcp logger interface" do
    aggregate_failures do
      logger.transport = :stdio
      logger.level = :info

      expect(logger.level).to eq(:info)
      expect(logger.stdio_transport?).to be(true)
      expect(logger.rack_transport?).to be(false)

      logger.transport = :rack
      expect(logger.rack_transport?).to be(true)

      expect { logger.debug("x") }.not_to raise_error
      expect { logger.info("x") }.not_to raise_error
      expect { logger.warn("x") }.not_to raise_error
      expect { logger.error("x") }.not_to raise_error
      expect { logger.fatal("x") }.not_to raise_error
      expect { logger.unknown("x") }.not_to raise_error

      expect(logger.client_initialized?).to be(false)
      logger.set_client_initialized(true)
      expect(logger.client_initialized?).to be(true)
      logger.set_client_initialized(false)
      expect(logger.client_initialized?).to be(false)
    end
  end
end
