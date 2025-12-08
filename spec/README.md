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

### Spec File Organization

This gem uses the **"Standard" Mirroring** approach: spec files mirror `lib/` structure 1-to-1.

```
lib/
└── scout_apm_mcp/
    ├── client.rb
    └── helpers.rb

spec/
└── scout_apm_mcp/
    ├── client_spec.rb
    └── helpers_spec.rb
```

**When to Split Specs:** If a spec file exceeds 300 lines or requires scrolling > 2 screens to find relevant `let` definitions, consider splitting into method-based files within a directory (e.g., `spec/scout_apm_mcp/client/list_apps_spec.rb`).

### Core Philosophy: Behavior Verification vs. Implementation Coupling

**Principle:** Tests should verify **what** the system does (behavior) via the public contract, not **how** it does it (implementation).

- **Behavior:** Defined by inputs accepted and observable outputs/side effects at architectural boundaries
- **Implementation:** Internal control flow, private methods, data structures, operation sequences

**Refactoring Resistance:** Tests should survive internal refactoring (renaming private methods, optimizing loops) without modification. If a test fails after refactoring that preserves behavior, the test is coupled to implementation.

### Core Principles

- **Always assume RSpec has been integrated** - Never edit `spec_helper.rb` or add new testing gems without careful consideration
- **Test Behavior, Not Implementation** - Verify the public contract, not internal structure
- **Refactoring Resistance** - Tests should survive internal refactoring without modification
- Keep test scope minimal - start with the most crucial and essential tests
- Never test features that are built into Ruby or external gems
- Never write tests for performance unless specifically requested
- Isolate external dependencies (HTTP calls, file system, time) at architectural boundaries only

### The Mocking Policy: Architectural Boundaries Only

**🚫 STRICTLY FORBIDDEN: Internal Mocks**

- **Never mock private/protected methods** - These are implementation details
- **Never create partial mocks of the SUT** - Don't stub methods within the class you're testing
- **Never use reflection to manipulate private state** - Test unreachable states

**✅ PERMITTED: Architectural Boundaries**

Mocking is reserved exclusively for systems the SUT does not own or control:

| Boundary Type | Examples | Preferred Double |
| :--- | :--- | :--- |
| **External I/O** | HTTP Clients (ScoutAPM API) | WebMock Stub |
| **System Env** | Environment Variables, Time | Stub (Fixed Values) |
| **File System** | Disk Access | Fake (Tempfile) |

### The Input Derivation Protocol

When you need to test a specific code path, **derive the input** that naturally triggers it instead of mocking internals.

1. **Analyze the Logic:** Examine conditional checks (`if`, `guard clauses`)
2. **Reverse Engineer the Input:** Determine the initial state that satisfies the predicate
3. **Construct Data:** Create a fixture that naturally satisfies the conditions
4. **Execute via Public API:** Pass the constructed input into the public entry point

**Example:** To test error handling when API key is missing, pass `nil` or empty string to the public method, don't mock `validate_api_key!`.

### Test Type Selection

#### Unit Specs (`spec/scout_apm_mcp/`)

- Use for: Class methods, instance methods, business logic, API interactions
- Test: Public API behavior, error handling, edge cases
- Example: Testing `ScoutApmMcp::Client` API methods, `ScoutApmMcp::Helpers` utility methods

### Testing Workflow

1. **Plan First**: Think carefully about what tests should be written for the given scope/feature
2. **Review Existing Tests**: Check existing specs before creating new test data
3. **Isolate Dependencies**: Use mocks/stubs for external services (HTTP APIs, environment variables)
4. **Use WebMock**: Set up WebMock for HTTP calls to external APIs
5. **Minimal Scope**: Start with essential tests, add edge cases only when specifically requested
6. **DRY Principles**: Review `spec/support/` for existing shared examples and helpers before duplicating code

### Test Data Management

#### Let/Let! Usage

- **`let`**: Lazy evaluation - only creates when accessed; use by default
- **`let!`**: Eager evaluation - creates immediately; use when laziness causes issues
- Keep `let` blocks close to where they're used
- Avoid creating unused data with `let!`

#### Test Data Patterns

For this gem, test data is typically:
- **API Keys**: Use environment variables or stubs for testing API key retrieval
- **API Responses**: Use WebMock to stub HTTP responses with realistic JSON data matching ScoutAPM API format
- **URLs**: Use generic, realistic ScoutAPM URLs for testing URL parsing

### Shared Contexts

- Use `spec/support/` for shared examples, custom matchers, and test helpers
- Create shared contexts for truly shared behavior across multiple spec files
- Scope helpers appropriately using `config.include` by spec type
- Keep shared contexts small: Under 50 lines per shared context file

### Isolation Best Practices

#### When to Isolate

- Expensive or flaky external IO (HTTP, environment variables) → stub or use WebMock
- Rare/error branches hard to trigger → stub to reach them
- Nondeterminism (time, random) → stub to deterministic values

#### When NOT to Isolate

- Standard library operations (unless truly slow/flaky)
- Cheap internal collaborations
- Where integration tests provide clearer coverage

#### Isolation Techniques

- **Verifying Doubles**: Prefer `instance_double(Class)`, `class_double` over plain `double` to catch interface mismatches
- **Stubs**: `allow(obj).to receive(:method).and_return(value)` for replacing behavior (external dependencies only)
- **Spies**: `expect(obj).to have_received(:method).with(args)` for verifying side effects (external dependencies only)
- **WebMock**: Stub HTTP requests for external services
- **Time Stubs**: Use `travel_to` or `Timecop` for deterministic time-dependent tests
- **Environment Variables**: Use `around` blocks to temporarily set/unset environment variables

#### Isolation Rules

1. **Preserve Public Behavior**: Test via public API, never test private methods directly
2. **Mock Only Boundaries**: Only mock external dependencies (HTTP, File System, Time, Environment), never internal methods
3. **Scope Narrowly**: Keep stubs local to examples; avoid global state and `allow_any_instance_of`
4. **Use Verifying Doubles**: Prefer `instance_double`, `class_double` over plain doubles
5. **Default to WebMock for HTTP**: Stub HTTP requests to avoid external dependencies
6. **Assert Outcomes**: Focus on behavior, not internal call choreography
7. **Input Derivation**: When you need to test a specific code path, derive the input that naturally triggers it

### WebMock Configuration

- WebMock is configured in `spec/support/webmock.rb`
- Stub HTTP requests to ScoutAPM API endpoints
- Use realistic response bodies matching ScoutAPM API format
- Filter sensitive data (API keys) in WebMock stubs

### Example Test Patterns

#### Testing API Client Methods

```ruby
RSpec.describe ScoutApmMcp::Client do
  describe "#list_apps" do
    it "returns list of apps" do
      # ✅ Mocking HTTP (architectural boundary) is allowed
      stub_request(:get, "https://scoutapm.com/api/v0/apps")
        .with(headers: { "X-SCOUT-API" => "test-key" })
        .to_return(
          status: 200,
          body: { results: { apps: [{ id: 1, name: "Test App" }] } }.to_json
        )

      client = ScoutApmMcp::Client.new(api_key: "test-key")
      result = client.list_apps

      # Assert behavior (what it returns), not implementation
      expect(result).to be_an(Array)
      expect(result.first["name"]).to eq("Test App")
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
      # ✅ Mocking HTTP error (architectural boundary)
      stub_request(:get, /scoutapm\.com\/api\/v0\/traces/)
        .to_return(status: 401, body: "Unauthorized")

      client = ScoutApmMcp::Client.new(api_key: "invalid-key")
      
      # Assert behavior (error handling)
      expect { client.fetch_trace(app_id: 1, trace_id: 1) }
        .to raise_error(ScoutApmMcp::AuthError, /Authentication failed/)
    end
  end
end
```

#### Anti-Pattern: Mocking Internal Methods

```ruby
# ❌ DO NOT DO THIS
RSpec.describe ScoutApmMcp::Client do
  it "validates API key" do
    client = described_class.new(api_key: "test-key")

    # VIOLATION: Mocking a method inside the SUT
    allow(client).to receive(:validate_api_key!).and_return(true)

    result = client.list_apps
    # ...
  end
end
```

#### Best Practice: Input Derivation

```ruby
# ✅ DO THIS
RSpec.describe ScoutApmMcp::Client do
  it "raises error when API key is missing" do
    # Input Derivation: Construct input that NATURALLY triggers validation error
    expect { described_class.new(api_key: "") }
      .to raise_error(ArgumentError, /API key/)
  end
end
```

### Code Quality Metrics

#### Target Metrics

| Metric | Target | Warning | Critical |
| :--- | :--- | :--- | :--- |
| **Spec file length** | < 100 lines | 100-300 lines | > 300 lines |
| **Example (`it`) length** | < 10 lines | 10-20 lines | > 20 lines |
| **Context nesting depth** | 2-3 levels | 4 levels | 5+ levels |
| **Shared context length** | < 50 lines | 50-100 lines | > 100 lines |

#### When to Refactor

- **Split a spec file** when it exceeds 300 lines or requires scrolling > 2 screens to find relevant `let` definitions
- **Extract shared context** when setup code is duplicated across 3+ spec files
- **Simplify a test** when an `it` block exceeds 15 lines or tests multiple behaviors

### Self-Correction Checklist

Before committing, perform this audit:

1. **Ownership Check:** Am I mocking a method that belongs to the class I am testing? (If YES → Delete mock)
2. **Verification Target:** Am I testing that the code works, or how the code works?
3. **Input Integrity:** Did I create the necessary input data to reach the code path naturally?
4. **Refactoring Resilience:** If I rename private helper methods, will this test still pass?
5. **Boundary Check:** Is the mock representing a true I/O boundary (HTTP, File System, Time, Environment)?
6. **Public API:** Am I testing through the public interface only?

### Anti-Patterns to Avoid

- **Mocking Internal Methods:** Never mock private/protected methods or methods within the class you're testing
- **Partial Mocks:** Never create partial mocks of the SUT (e.g., `allow(service).to receive(:internal_method)`)
- **Testing Implementation Details:** Don't assert that specific private methods were called
- **Reflection-Based Manipulation:** Don't use reflection to set private fields
- **Not Isolating Boundaries:** Always isolate external dependencies (HTTP, file system, time, environment)
- **Using Real External Services:** Never use real external services in tests
- **Testing Ruby/Gem Functionality:** Don't test features built into Ruby or external gems
- **Over-Testing Edge Cases:** Only test edge cases when specifically requested
- **Creating Unnecessary Data:** Avoid creating unused test data with `let!`
- **Using `allow_any_instance_of`:** Prefer proper dependency injection and stubbing
- **Global Stubs:** Avoid global stubs causing test pollution
- **Not Cleaning Up:** Always clean up environment variables between tests
