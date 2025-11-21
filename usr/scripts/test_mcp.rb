#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for MCP server
# This script sends JSON-RPC messages to test the MCP server

require "json"
require "open3"

# Test the MCP server by sending initialize request
def test_mcp_server
  puts "Testing MCP server..."

  # Start the server process
  cmd = "bundle exec scout_apm_mcp"

  Open3.popen2(cmd) do |stdin, stdout, wait_thr|
    # Send initialize request (MCP protocol requires this first)
    init_request = {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: {
          name: "test-client",
          version: "1.0.0"
        }
      }
    }

    puts "Sending initialize request..."
    stdin.puts(init_request.to_json)
    stdin.flush

    # Wait a bit for response
    sleep 0.5

    # Try to read response
    init_success = false
    begin
      if select([stdout], nil, nil, 1)
        response = stdout.gets
        if response
          puts "Initialize response received:"
          parsed = JSON.parse(response)
          puts JSON.pretty_generate(parsed)

          if parsed["result"]
            puts "\n✓ Server initialized successfully!"
            init_success = true
          elsif parsed["error"]
            puts "\n✗ Server returned error:"
            puts JSON.pretty_generate(parsed["error"])
            return false
          end
        end
      else
        puts "No response received within timeout"
        return false
      end
    rescue => e
      puts "Error reading response: #{e.message}"
      return false
    end

    return false unless init_success

    # Send initialized notification (required after initialize)
    initialized_notification = {
      jsonrpc: "2.0",
      method: "notifications/initialized"
    }

    puts "\nSending initialized notification..."
    stdin.puts(initialized_notification.to_json)
    stdin.flush
    sleep 0.2

    # Now try to list tools
    list_tools_request = {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/list"
    }

    puts "Sending tools/list request..."
    stdin.puts(list_tools_request.to_json)
    stdin.flush
    sleep 0.5

    # Read tools list response
    begin
      if select([stdout], nil, nil, 1)
        response = stdout.gets
        if response
          puts "\nTools list response received:"
          parsed = JSON.parse(response)
          puts JSON.pretty_generate(parsed)

          if parsed["result"] && parsed["result"]["tools"]
            tool_count = parsed["result"]["tools"].length
            puts "\n✓ Found #{tool_count} tools available!"
            return true
          elsif parsed["error"]
            puts "\n✗ Server returned error:"
            puts JSON.pretty_generate(parsed["error"])
            return false
          end
        end
      else
        puts "No response received within timeout"
        return false
      end
    rescue => e
      puts "Error reading response: #{e.message}"
      return false
    ensure
      stdin.close
      wait_thr.kill if wait_thr.alive?
    end
  end
rescue => e
  puts "Error testing MCP server: #{e.message}"
  puts e.backtrace.first(5)
  false
end

if test_mcp_server
  puts "\n✓ MCP server test passed!"
  exit 0
else
  puts "\n✗ MCP server test failed!"
  exit 1
end
