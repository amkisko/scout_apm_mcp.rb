# frozen_string_literal: true

RSpec.shared_context "with server integration" do
  let(:server) do
    FastMcp::Server.new(
      name: "scout-apm",
      version: ScoutApmMcp::VERSION,
      logger: ScoutApmMcp::Server::NullLogger.new
    )
  end

  let(:transport) { FastMcp::Transports::StdioTransport.new(server) }

  before do
    described_class.register_tools(server)
    server.instance_variable_set(:@transport, transport)
    allow(ScoutApmMcp::Helpers).to receive(:get_api_key).and_return("test-api-key")
  end

  def with_captured_stdout(&block)
    original_stdout = $stdout
    $stdout = StringIO.new
    block.call
  ensure
    $stdout = original_stdout
  end
end
