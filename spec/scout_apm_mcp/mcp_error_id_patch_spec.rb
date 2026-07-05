require "spec_helper"
require "scout_apm_mcp/server"

RSpec.describe "MCP error id patch" do
  let(:logger) { ScoutApmMcp::Server::NullLogger.new }

  it "assigns a synthetic id when Server#send_error is called with a nil id" do
    server = FastMcp::Server.new(name: "test", version: "1.0", logger: logger)
    captured_response = nil
    allow(server).to receive(:send_response) { |response| captured_response = response }

    server.__send__(:send_error, -32600, "bad request", nil)

    expect(captured_response[:id]).to match(/\Aerror_[0-9a-f]{16}\z/)
  end

  it "preserves an explicit id when Server#send_error is called with one" do
    server = FastMcp::Server.new(name: "test", version: "1.0", logger: logger)
    captured_response = nil
    allow(server).to receive(:send_response) { |response| captured_response = response }

    server.__send__(:send_error, -32600, "bad request", 42)

    expect(captured_response[:id]).to eq(42)
  end
end
