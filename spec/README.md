# Running Tests

## Using rspec

All tests should be run using `bin/rspec` or `bundle exec rspec`

```bash
# Run all tests
bin/rspec

# Run with fail-fast (stop on first failure)
bin/rspec --fail-fast

# For verbose output
DEBUG=1 bin/rspec

# Run single spec file at exact line number
DEBUG=1 bin/rspec spec/scout_apm_mcp/client_spec.rb:10
```

## Test Structure

- `spec/scout_apm_mcp/` - Specs for gem modules and classes
  - `client_spec.rb` - ScoutAPM API client tests
  - `helpers_spec.rb` - Helper methods for API key management and URL parsing
- `spec/support/` - Shared test helpers and configuration
  - `webmock.rb` - WebMock configuration for HTTP request stubbing

## RSpec Testing Guidelines

### Core Principles

- **Always assume RSpec has been integrated** - Never edit `spec_helper.rb` or add new testing gems without careful consideration
- Focus on testing behavior, not implementation details
- Keep test scope minimal - start with the most crucial and essential tests
- Never test features that are built into Ruby or standard libraries
- Never write tests for performance unless specifically requested

### Test Type Selection

#### Unit Specs (`spec/scout_apm_mcp/`)

- Use for: Class methods, instance methods, business logic, API interactions
- Test: Public API behavior, error handling, edge cases
- Example: Testing `ScoutApmMcp::Client` API methods, `ScoutApmMcp::Helpers` utility methods

### Testing Workflow

1. **Plan First**: Think carefully about what tests should be written for the given scope/feature
2. **Isolate Dependencies**: Use mocks/stubs for external services (HTTP APIs, 1Password CLI)
3. **Use WebMock**: Set up WebMock for HTTP calls to external APIs
4. **Minimal Scope**: Start with essential tests, add edge cases only when specifically requested
5. **DRY Principles**: Review `spec/support/` for existing shared examples and helpers before duplicating code

### Test Data Management

#### Let/Let! Usage

- **`let`**: Lazy evaluation - only creates when accessed; use by default
- **`let!`**: Eager evaluation - creates immediately; use when laziness causes issues
- Keep `let` blocks close to where they're used
- Avoid creating unused data with `let!`

#### Test Data Patterns

For this gem, test data is typically:
- **API Keys**: Use environment variables or stubs for testing API key retrieval
- **API Responses**: Use WebMock to stub HTTP responses with realistic JSON data
- **URLs**: Use generic, realistic ScoutAPM URLs for testing URL parsing

### Shared Contexts

- Use `spec/support/` for shared examples, custom matchers, and test helpers
- Create shared contexts for truly shared behavior across multiple spec files
- Scope helpers appropriately using `config.include` by spec type

### Isolation Best Practices

#### When to Isolate

- Expensive or flaky external IO (HTTP, CLI commands, environment variables) → stub or use WebMock
- Rare/error branches hard to trigger → stub to reach them
- Nondeterminism (random, time, UUIDs) → stub to deterministic values
- Performance in tight unit scopes → replace heavy collaborators

#### When NOT to Isolate

- Standard library operations (unless truly slow/flaky)
- Cheap internal collaborations
- Where integration tests provide clearer coverage

#### Isolation Techniques

- **Verifying Doubles**: Prefer `instance_double(ScoutApmMcp::Client)`, `class_double` over plain `double` to catch interface mismatches
- **Stubs**: `allow(obj).to receive(:method).and_return(value)` for replacing behavior
- **Spies**: `expect(obj).to have_received(:method).with(args)` for verifying side effects
- **WebMock**: Stub HTTP interactions for external API calls
- **Time Stubs**: Use `travel_to` or `Timecop` for deterministic time-dependent tests
- **Sequential Returns**: `and_return(value1, value2)` for modeling retries and fallbacks
- **Environment Variables**: Use `around` blocks to temporarily set/unset environment variables

#### Isolation Rules

1. **Preserve Public Behavior**: Test via public API, never test private methods directly
2. **Scope Narrowly**: Keep stubs local to examples; avoid global state and `allow_any_instance_of`
3. **Use Verifying Doubles**: Prefer `instance_double`, `class_double` over plain doubles
4. **Default to WebMock for HTTP**: Stub external API calls to avoid network dependencies
5. **Assert Outcomes**: Focus on behavior, not internal call choreography

### WebMock Configuration

- WebMock is configured in `spec/support/webmock.rb`
- Stub HTTP requests to ScoutAPM API endpoints
- Use realistic response bodies matching ScoutAPM API format
- Filter sensitive data (API keys) in WebMock stubs

### Example Test Patterns

#### Testing API Client Methods

```ruby
RSpec.describe ScoutApmMcp::Client do
  describe "#fetch_apps" do
    it "returns list of apps" do
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: { "X-SCOUT-API" => "test-key" })
        .to_return(
          status: 200,
          body: [{ id: 1, name: "Test App" }].to_json
        )

      client = ScoutApmMcp::Client.new(api_key: "test-key")
      result = client.fetch_apps

      expect(result).to be_an(Array)
      expect(result.first[:name]).to eq("Test App")
    end
  end
end
```

#### Testing Environment Variable Handling

```ruby
RSpec.describe ScoutApmMcp::Helpers do
  describe ".get_api_key" do
    context "when API_KEY environment variable is set" do
      around do |example|
        original = ENV["API_KEY"]
        ENV["API_KEY"] = "env-api-key"
        example.run
        ENV["API_KEY"] = original
      end

      it "returns the API key from environment" do
        result = described_class.get_api_key
        expect(result).to eq("env-api-key")
      end
    end
  end
end
```

#### Testing Error Handling

```ruby
RSpec.describe ScoutApmMcp::Client do
  describe "#fetch_trace" do
    it "raises error on authentication failure" do
      stub_request(:get, /scoutapm\.com\/api\/v0\/traces/)
        .to_return(status: 401, body: "Unauthorized")

      client = ScoutApmMcp::Client.new(api_key: "invalid-key")
      
      expect { client.fetch_trace(app_id: 1, trace_id: 1) }
        .to raise_error(/Authentication failed/)
    end
  end
end
```

### Anti-Patterns to Avoid

- Testing implementation details over behavior
- Not isolating external dependencies (HTTP, CLI, environment)
- Over-testing edge cases without being asked
- Testing Ruby standard library features
- Writing tests without reviewing existing helpers
- Global stubs causing test pollution
- Not cleaning up environment variables between tests

