# Security Policy

## Supported Versions

We actively support the following versions of `scout_apm_mcp` with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in `scout_apm_mcp`, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email security details to: **contact@kiskolabs.com**
3. Include the following information:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### Response Timeline

- We will acknowledge receipt of your report within **48 hours**
- We will provide an initial assessment within **7 days**
- We will keep you informed of our progress and resolution timeline

### Disclosure Policy

- We will work with you to understand and resolve the issue quickly
- We will credit you for the discovery (unless you prefer to remain anonymous)
- We will publish a security advisory after the vulnerability is patched
- We will coordinate public disclosure with you

## Security Considerations

### API Key Management

**CRITICAL**: Never commit API keys to version control.

This gem supports multiple secure methods for API key retrieval:

1. **1Password Integration** (Recommended): Use `OP_ENV_ENTRY_PATH` environment variable
2. **Environment Variables**: Set `API_KEY` or `SCOUT_APM_API_KEY` in your shell environment
3. **1Password CLI**: Automatic fallback to 1Password CLI if available

**Best Practices:**
- Store API keys in secure credential management systems (1Password, AWS Secrets Manager, HashiCorp Vault, etc.)
- Use `.gitignore` to exclude configuration files containing credentials
- Never hardcode API keys in configuration files or source code
- Rotate API keys regularly according to your security policy
- Use different API keys for development, staging, and production

**Example secure configuration:**
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

### Network Security

- All API requests use HTTPS to ScoutAPM API
- The gem validates SSL certificates by default
- Network requests are made to trusted ScoutAPM endpoints (scoutapm.com)

### Input Validation

- Application IDs, endpoint IDs, and trace IDs are validated before making API requests
- URL parameters are properly encoded
- The gem handles network errors and malformed responses gracefully
- API responses are validated before processing

### Data Handling

**What this gem does:**
- Fetches application performance monitoring data from ScoutAPM API
- Provides MCP server tools for querying APM data
- Caches API responses temporarily for performance

**What this gem does NOT do:**
- Store API keys in plain text files
- Log sensitive data (API keys, tokens, etc.)
- Transmit data to third-party services
- Execute arbitrary code or commands

### Logging and Monitoring

**Sensitive Data:**
- Never log API keys, tokens, or authorization codes
- Log security events (authentication failures, API errors, etc.)
- Use structured logging for security analysis

**Example:**
```ruby
# ✅ Good: Log security events without sensitive data
Rails.logger.info("ScoutAPM API request initiated", {
  app_id: app_id,
  endpoint: endpoint_name,
  timestamp: Time.now
})

# ❌ Bad: Log sensitive data
Rails.logger.info("API Key: #{api_key}")
```

### Dependency Security

Keep dependencies up to date:

```bash
# Check for security vulnerabilities
bundle audit

# Update dependencies regularly
bundle update
```

### Error Handling

**Security Considerations:**
- Don't expose internal error details or API keys in error messages
- Log errors securely (without sensitive data)
- Use generic error messages for authentication failures
- Implement proper error handling to prevent information leakage

## Security Updates

Security updates will be released as patch versions (e.g., 0.1.0 → 0.1.1) for supported versions.

For critical security vulnerabilities, we may release a security advisory and recommend immediate upgrade.

## Security Checklist

Before deploying to production:

- [ ] API keys are stored securely (not in version control)
- [ ] Configuration uses environment variables or secure credential management
- [ ] SSL verification is enabled (default)
- [ ] Logging excludes sensitive data
- [ ] Dependencies are up to date (`bundle audit`)
- [ ] Error handling doesn't expose sensitive information
- [ ] API keys are rotated regularly
- [ ] Different API keys are used for development, staging, and production

## Additional Resources

- [ScoutAPM Security](https://scoutapm.com/security)
- [Ruby Security Guide](https://www.ruby-lang.org/en/documentation/security/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [1Password Security](https://1password.com/security/)

## Contact

For security concerns, contact: **contact@kiskolabs.com**

For general support, open an issue on GitHub: https://github.com/amkisko/scout_apm_mcp.rb/issues

