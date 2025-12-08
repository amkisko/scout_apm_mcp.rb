require "simplecov"
require "simplecov-cobertura"
require "simplecov_json_formatter"

SimpleCov.start do
  track_files "{lib,app}/**/*.rb"
  add_filter "/lib/scout_apm_mcp/version.rb"
  add_filter "/lib/tasks/"
  add_filter "/spec/"
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
end

require "rspec"
require "webmock/rspec"
require_relative "../lib/scout_apm_mcp"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require_relative f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
