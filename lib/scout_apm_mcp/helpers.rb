require "uri"
require "base64"
require "time"
require "open3"

require_relative "helpers/api_key_resolver"
require_relative "helpers/scout_url_parser"
require_relative "helpers/identifiers"
require_relative "helpers/time_range"

module ScoutApmMcp
  # Helper module for API key management, URL parsing, and time utilities
  module Helpers
    class << self
      include ApiKeyResolver
      include ScoutUrlParser
      include Identifiers
      include TimeRange
    end
  end
end
