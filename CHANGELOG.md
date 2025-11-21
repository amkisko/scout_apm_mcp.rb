# CHANGELOG

## 0.1.3 (2025-11-21)

- Custom exception classes (`ScoutApmMcp::Error`, `ScoutApmMcp::AuthError`, `ScoutApmMcp::APIError`) for better error handling
- Input validation for metric types (`VALID_METRICS` constant) and insight types (`VALID_INSIGHTS` constant)
- Time range validation (ensures from_time < to_time and range doesn't exceed 2 weeks)
- Trace age validation (ensures trace queries aren't older than 7 days)
- Client methods now return extracted data instead of full API response structure
- Time/Duration helpers (`Helpers.format_time`, `Helpers.parse_time`, `Helpers.make_duration`)
- Endpoint ID extraction helper (`Helpers.get_endpoint_id`)
- User-Agent header (`scout-apm-mcp-rb/VERSION`) on all API requests
- `active_since` parameter to `list_apps` method for filtering apps by last reported time
- API-level error parsing - checks for `header.status.code` in response body
- Error handling now uses custom exception classes instead of generic `RuntimeError`
- MCP `ListAppsTool` now supports optional `active_since` parameter
- Error responses now properly parse API-level error codes from response body
- Invalid metric types, insight types, and time ranges are now validated before API calls

## 0.1.2 (2025-11-21)

- Enhanced SSL certificate handling with support for `SSL_CERT_FILE` environment variable and automatic fallback to system certificates
- Improved error handling for SSL verification failures with clearer error messages
- Extended `Helpers.parse_scout_url` to support parsing multiple URL types (endpoints, error_groups, insights, apps) beyond just traces
- Added `FetchScoutURLTool` MCP tool for automatically detecting and fetching data from any ScoutAPM URL
- Fixed MCP error handling to ensure error responses always have valid IDs for strict MCP client validation
- Improved URL parsing to return `url_type` field for better resource type detection

## 0.1.1 (2025-11-21)

- Fixed `NullLogger` missing `set_client_initialized` method that caused MCP initialization errors
- Added `set_client_initialized` method with optional argument to match fast-mcp logger interface

## 0.1.0 (2025-11-20)

- Initial release
- ScoutAPM API client with full endpoint coverage (applications, metrics, endpoints, traces, errors, insights, OpenAPI)
- MCP server integration for Cursor IDE with executable `bundle exec scout_apm_mcp`
- Helper methods for API key management and URL parsing (`Helpers.get_api_key`, `Helpers.parse_scout_url`, `Helpers.decode_endpoint_id`)
- Support for environment variables and 1Password integration (via optional `opdotenv` gem)
- Complete RBS type signatures for all public APIs
- Comprehensive test suite with RSpec
- Requires Ruby 3.1 or higher
- All dependencies use latest compatible versions with pessimistic versioning for security
