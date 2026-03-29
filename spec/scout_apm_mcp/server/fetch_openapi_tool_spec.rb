require "spec_helper"
require "scout_apm_mcp/server"
require "scout_apm_mcp/server/shared_contexts"
require "json"
require "tmpdir"

RSpec.describe ScoutApmMcp::Server, "#handle_request" do
  include_context "with server integration"

  let(:mock_client) { instance_double(ScoutApmMcp::Client) }
  let(:schema_payload) do
    {
      content: "openapi: 3.0.3\ninfo:\n  title: T\n",
      content_type: "application/x-yaml",
      status: 200
    }
  end

  before do
    allow(ScoutApmMcp::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:fetch_openapi_schema).and_return(schema_payload)
  end

  def parse_response(io_response)
    io_response.rewind
    JSON.parse(io_response.read)
  end

  def call_openapi(validate: false, compare_with_local: false)
    req = {
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: "ScoutApmMcpServerFetchOpenAPISchemaTool",
        arguments: {validate: validate, compare_with_local: compare_with_local}
      },
      id: 1
    }
    io_response = with_captured_stdout { server.handle_request(JSON.generate(req)) }
    parse_response(io_response)
  end

  it "returns YAML validation metadata when validate is true" do
    res = call_openapi(validate: true)
    text = res.dig("result", "content", 0, "text")
    aggregate_failures do
      expect(text).to include("valid_yaml")
      expect(text).to include("3.0.3")
    end
  end

  it "records validation_error when YAML cannot be parsed" do
    allow(mock_client).to receive(:fetch_openapi_schema).and_return(
      schema_payload.merge(content: "{not valid yaml !!!")
    )

    res = call_openapi(validate: true)
    text = res.dig("result", "content", 0, "text")
    aggregate_failures do
      expect(text).to include("valid_yaml")
      expect(text).to include("validation_error")
    end
  end

  it "reports when tmp/scoutapm_openapi.yaml does not exist" do
    missing = "/tmp/scoutapm_openapi_absent_#{Process.pid}"
    allow(File).to receive(:expand_path).with("tmp/scoutapm_openapi.yaml").and_return(missing)

    res = call_openapi(compare_with_local: true)
    text = res.dig("result", "content", 0, "text")
    aggregate_failures do
      expect(text).to include("local_file_exists")
      expect(text).to include("false")
    end
  end

  it "compares remote schema to a local file when paths differ" do
    dir = Dir.mktmpdir
    path = File.join(dir, "scoutapm_openapi.yaml")
    File.write(path, "openapi: 3.0.0\n")

    allow(File).to receive(:expand_path).with("tmp/scoutapm_openapi.yaml").and_return(path)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(path).and_return(true)

    res = call_openapi(compare_with_local: true)
    text = res.dig("result", "content", 0, "text")
    aggregate_failures do
      expect(text).to include("content_matches")
      expect(text).to include("structure_matches")
      expect(text).to include("remote_paths_count")
    end
  end

  it "skips YAML structure diff when remote and local strings match" do
    dir = Dir.mktmpdir
    path = File.join(dir, "scoutapm_openapi.yaml")
    File.write(path, schema_payload[:content])

    allow(File).to receive(:expand_path).with("tmp/scoutapm_openapi.yaml").and_return(path)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(path).and_return(true)

    res = call_openapi(compare_with_local: true)
    text = res.dig("result", "content", 0, "text")
    expect(text).to match(/content_matches:\s*true/)
  end

  it "captures comparison_error when YAML parsing fails during diff" do
    dir = Dir.mktmpdir
    path = File.join(dir, "scoutapm_openapi.yaml")
    File.write(path, "remote: matches\n")

    allow(File).to receive(:expand_path).with("tmp/scoutapm_openapi.yaml").and_return(path)

    calls = 0
    allow(YAML).to receive(:safe_load).and_wrap_original do |method, *args|
      calls += 1
      raise Psych::SyntaxError, "forced" if calls == 2
      method.call(*args)
    end

    res = call_openapi(compare_with_local: true)
    text = res.dig("result", "content", 0, "text")
    expect(text).to include("comparison_error")
  end
end
