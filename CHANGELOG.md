# CHANGELOG

## 0.1.0 (2025-11-20)

- Initial release
- ScoutAPM API client with full endpoint coverage (applications, metrics, endpoints, traces, errors, insights, OpenAPI)
- MCP server integration for Cursor IDE with executable `bundle exec scout_apm_mcp`
- Helper methods for API key management and URL parsing (`Helpers.get_api_key`, `Helpers.parse_scout_url`, `Helpers.decode_endpoint_id`)
- Support for environment variables and 1Password integration (via optional `opdotenv` gem)
- Complete RBS type signatures for all public APIs
- Comprehensive test suite with RSpec
- Requires Ruby 3.0 or higher
- All dependencies use latest compatible versions with pessimistic versioning for security
