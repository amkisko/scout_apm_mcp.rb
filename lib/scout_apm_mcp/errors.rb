module ScoutApmMcp
  # Base exception for Scout APM SDK errors
  class Error < StandardError; end

  # Raised when authentication fails
  class AuthError < Error; end

  # Raised when the API returns an error response
  class APIError < Error
    attr_reader :status_code, :response_data

    def initialize(message, status_code: nil, response_data: nil)
      super(message)
      @status_code = status_code
      @response_data = response_data
    end
  end
end
