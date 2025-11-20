# scout_apm_mcp

[![Gem Version](https://badge.fury.io/rb/scout_apm_mcp.svg)](https://badge.fury.io/rb/scout_apm_mcp) [![Test Status](https://github.com/amkisko/scout_apm_mcp.rb/actions/workflows/test.yml/badge.svg)](https://github.com/amkisko/scout_apm_mcp.rb/actions/workflows/test.yml) [![codecov](https://codecov.io/gh/amkisko/scout_apm_mcp.rb/graph/badge.svg?token=UX80FTO0Y0)](https://codecov.io/gh/amkisko/scout_apm_mcp.rb)

Ruby gem providing ScoutAPM API client and MCP (Model Context Protocol) server tools for fetching traces, endpoints, metrics, errors, and insights. Integrates with MCP-compatible clients like Cursor IDE, Claude Desktop, and other MCP-enabled tools.

Sponsored by [Kisko Labs](https://www.kiskolabs.com).

<a href="https://www.kiskolabs.com">
  <img src="kisko.svg" width="200" alt="Sponsored by Kisko Labs" />
</a>

## Requirements

- **Ruby 3.0 or higher** (Ruby 2.7 and earlier are not supported)

## Quick Start

1. In scoutapm create API key under Organization settings: https://scoutapm.com/settings
2. In 1Password create an item with the name "Scout APM API" and store the API key in a new field named API_KEY
3. Configure your favorite service to use local MCP server, ensure OP_ENV_ENTRY_PATH has correct vault and item names (both are visible in 1Password UI)

### Cursor IDE Configuration

For Cursor IDE, create or update `.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "scout-apm": {
      "command": "bundle",
      "args": ["exec", "scout_apm_mcp"],
      "env": {
        "OP_ENV_ENTRY_PATH": "op://Vault Name/Item Name"
      }
    }
  }
}
```

Or if installed globally:

```json
{
  "mcpServers": {
    "scout-apm": {
      "command": "scout_apm_mcp",
      "env": {
        "OP_ENV_ENTRY_PATH": "op://Vault Name/Item Name"
      }
    }
  }
}
```

### Claude Desktop Configuration

For Claude Desktop, edit the MCP configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`  
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "scout-apm": {
      "command": "bundle",
      "args": ["exec", "scout_apm_mcp"],
      "cwd": "/path/to/your/project"
    }
  }
}
```

Or if installed globally:

```json
{
  "mcpServers": {
    "scout-apm": {
      "command": "scout_apm_mcp"
    }
  }
}
```

**Note**: After updating the configuration, restart Claude Desktop for changes to take effect.

### Security Best Practice

Do not store API keys or tokens in MCP configuration files. Instead, use one of these methods:

1. **1Password Integration**: Set `OP_ENV_ENTRY_PATH` environment variable (e.g., `op://Vault/Item`) to automatically load credentials via opdotenv
2. **1Password CLI**: The gem will automatically fall back to 1Password CLI if opdotenv is not available
3. **Environment Variables**: Set `API_KEY` or `SCOUT_APM_API_KEY` in your shell environment (not recommended for production - use secret vault for in-memory provisioning)

The gem will automatically detect and use credentials from your environment or 1Password integration.

### Testing with MCP Inspector

You can test the MCP server using the [MCP Inspector](https://github.com/modelcontextprotocol/inspector) tool:

```bash
# Set your 1Password entry path (or use API_KEY/SCOUT_APM_API_KEY)
export OP_ENV_ENTRY_PATH="op://Vault/Scout APM"

# Run the MCP inspector with the server
npx @modelcontextprotocol/inspector bundle exec scout_apm_mcp
```

The inspector will:
1. Start a proxy server and open a browser interface
2. Connect to your MCP server via STDIO
3. Allow you to test all available tools interactively
4. Display request/response messages and any errors

This is useful for:
- Testing tool functionality before integrating with MCP clients
- Debugging MCP protocol communication
- Verifying API key configuration
- Exploring available tools and their parameters

### Running the MCP Server manually

After installation, you can start the MCP server immediately:

```bash
# With bundler
gem install scout_apm_mcp && bundle exec scout_apm_mcp

# Or if installed globally
scout_apm_mcp
```

The server will start and communicate via STDIN/STDOUT using the MCP protocol. Make sure you have your ScoutAPM API key configured (see API Key Management section below).

## Features

- **ScoutAPM API Client**: Full-featured client for ScoutAPM REST API
- **MCP Server Integration**: Ready-to-use MCP server compatible with Cursor IDE, Claude Desktop, and other MCP-enabled tools
- **API Key Management**: Supports environment variables and 1Password integration (via optional `opdotenv` gem)
- **URL Parsing**: Helper methods to parse ScoutAPM URLs and extract IDs
- **Comprehensive API Coverage**: Supports all ScoutAPM API endpoints (apps, metrics, endpoints, traces, errors, insights)

## Basic Usage

### API Client

```ruby
require "scout_apm_mcp"

# Get API key (from environment or 1Password)
api_key = ScoutApmMcp::Helpers.get_api_key

# Create client
client = ScoutApmMcp::Client.new(api_key: api_key)

# List applications
apps = client.list_apps

# Get application details
app = client.get_app(123)

# List endpoints
endpoints = client.list_endpoints(123)

# Fetch trace
trace = client.fetch_trace(123, 456)

# Get metrics
metrics = client.get_metric(123, "response_time", from: "2025-01-01T00:00:00Z", to: "2025-01-02T00:00:00Z")

# List error groups
errors = client.list_error_groups(123, from: "2025-01-01T00:00:00Z", to: "2025-01-02T00:00:00Z")

# Get insights
insights = client.get_all_insights(123, limit: 20)
```

### URL Parsing

```ruby
# Parse a ScoutAPM trace URL
url = "https://scoutapm.com/apps/123/endpoints/.../trace/456"
parsed = ScoutApmMcp::Helpers.parse_scout_url(url)
# => { app_id: 123, endpoint_id: "...", trace_id: 456, decoded_endpoint: "...", query_params: {...} }
```

### API Key Management

The gem supports multiple methods for API key retrieval (checked in order):

1. **Direct parameter**: Pass `api_key:` when calling `Helpers.get_api_key`
2. **Environment variable**: Set `API_KEY` or `SCOUT_APM_API_KEY`
3. **1Password via OP_ENV_ENTRY_PATH**: Set `OP_ENV_ENTRY_PATH` environment variable (e.g., `op://Vault/Item`)
4. **1Password via opdotenv**: Automatically loads from 1Password if `opdotenv` gem is available and `op_vault`/`op_item` are provided
5. **1Password CLI**: Falls back to direct `op` CLI command

```ruby
# From environment variable (recommended: use in-memory vault or shell environment)
# Set API_KEY or SCOUT_APM_API_KEY in your environment
api_key = ScoutApmMcp::Helpers.get_api_key

# From 1Password using OP_ENV_ENTRY_PATH (recommended for 1Password users)
# Set OP_ENV_ENTRY_PATH in your environment (e.g., op://Vault/Item)
ENV["OP_ENV_ENTRY_PATH"] = "op://YourVault/YourItem"
api_key = ScoutApmMcp::Helpers.get_api_key

# From 1Password with explicit vault/item (requires opdotenv gem or op CLI)
api_key = ScoutApmMcp::Helpers.get_api_key(
  op_vault: "YourVault",
  op_item: "Your ScoutAPM API",
  op_field: "API_KEY"
)
```

**Security Note**: Never hardcode API keys in your code or configuration files. Always use environment variables, in-memory vaults, or secure credential management systems like 1Password.

## API Methods

### Applications

- `list_apps` - List all applications
- `get_app(app_id)` - Get application details

### Metrics

- `list_metrics(app_id)` - List available metric types
- `get_metric(app_id, metric_type, from:, to:)` - Get time-series metric data

### Endpoints

- `list_endpoints(app_id, from:, to:)` - List all endpoints
- `get_endpoint(app_id, endpoint_id)` - Get endpoint details
- `get_endpoint_metrics(app_id, endpoint_id, metric_type, from:, to:)` - Get endpoint metrics
- `list_endpoint_traces(app_id, endpoint_id, from:, to:)` - List endpoint traces

### Traces

- `fetch_trace(app_id, trace_id)` - Fetch detailed trace information

### Errors

- `list_error_groups(app_id, from:, to:, endpoint:)` - List error groups
- `get_error_group(app_id, error_id)` - Get error group details
- `get_error_group_errors(app_id, error_id)` - Get errors within a group

### Insights

- `get_all_insights(app_id, limit:)` - Get all insight types
- `get_insight_by_type(app_id, insight_type, limit:)` - Get specific insight type
- `get_insights_history(app_id, from:, to:, limit:, pagination_cursor:, pagination_direction:, pagination_page:)` - Get historical insights
- `get_insights_history_by_type(app_id, insight_type, from:, to:, limit:, pagination_cursor:, pagination_direction:, pagination_page:)` - Get historical insights by type

### OpenAPI Schema

- `fetch_openapi_schema` - Fetch the ScoutAPM OpenAPI schema

## MCP Server Integration

This gem includes a ready-to-use MCP server that can be run directly:

```bash
# After installing the gem
bundle exec scout_apm_mcp
```

Or if installed globally:

```bash
gem install scout_apm_mcp
scout_apm_mcp
```

The server will communicate via STDIN/STDOUT using the MCP protocol. Configure it in your MCP client (e.g., Cursor IDE, Claude Desktop, or other MCP-enabled tools).

## Error Handling

The client raises exceptions for API errors:

- `RuntimeError` with message containing "Authentication failed" for 401 Unauthorized
- `RuntimeError` with message containing "Resource not found" for 404 Not Found
- `RuntimeError` with message containing "API request failed" for other HTTP errors

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run tests across multiple Ruby versions
bundle exec appraisal install
bundle exec appraisal rspec

# Run linting
bundle exec standardrb --fix

# Validate RBS type signatures
bundle exec rbs validate
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amkisko/scout_apm_mcp.rb.

Contribution policy:
- New features are not necessarily added to the gem
- Pull request should have test coverage for affected parts
- Pull request should have changelog entry

Review policy:
- It might take up to 2 calendar weeks to review and merge critical fixes
- It might take up to 6 calendar months to review and merge pull request
- It might take up to 1 calendar year to review an issue

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.md).

