module ScoutApmMcp
  class Client
    module HttpTransport
      private

      def build_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 10
        http.open_timeout = 10
        configure_ssl(http, uri) if uri.scheme == "https"
        http
      end

      def make_request(uri)
        attempt = 0

        loop do
          attempt += 1
          return perform_request(uri)
        rescue APIError => error
          retry_api_error!(error, attempt)
        rescue OpenSSL::SSL::SSLError => error
          raise_ssl_error(error)
        rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT => error
          retry_connection_error!(error, attempt)
        rescue Error
          raise
        rescue => error
          raise Error, "Request failed: #{error.class} - #{error.message}"
        end
      end

      def perform_request(uri)
        http = build_http_client(uri)
        request = build_json_request(uri)
        response = http.request(request)
        response_data = handle_response_errors(response)
        validate_api_status_header(response_data)
        response_data
      end

      def handle_response_errors(response)
        data = parse_response_body(response)

        case response
        when Net::HTTPSuccess
          data
        when Net::HTTPUnauthorized
          raise AuthError, "Authentication failed - check your API key"
        when Net::HTTPNotFound
          raise APIError.new("Resource not found", status_code: 404, response_data: data)
        else
          raise_api_error(response, data)
        end
      end

      def fetch_openapi_schema_response(uri)
        http = build_http_client(uri)
        request = build_openapi_request(uri)
        response = http.request(request)
        handle_openapi_response(response)
      rescue OpenSSL::SSL::SSLError => error
        raise_ssl_error(error)
      rescue Error
        raise
      rescue => error
        raise Error, "Request failed: #{error.class} - #{error.message}"
      end

      def configure_ssl(http, uri)
        return unless uri.scheme == "https"

        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ca_file = ssl_certificate_file
        http.ca_file = ca_file if ca_file
      end

      def ssl_certificate_file
        if ENV["SSL_CERT_FILE"] && File.file?(ENV["SSL_CERT_FILE"])
          ENV["SSL_CERT_FILE"]
        elsif File.exist?(OpenSSL::X509::DEFAULT_CERT_FILE)
          OpenSSL::X509::DEFAULT_CERT_FILE
        end
      end

      def build_json_request(uri)
        request = Net::HTTP::Get.new(uri)
        request["X-SCOUT-API"] = @api_key
        request["User-Agent"] = @user_agent
        request["Accept"] = "application/json"
        request
      end

      def build_openapi_request(uri)
        request = Net::HTTP::Get.new(uri)
        request["X-SCOUT-API"] = @api_key
        request["User-Agent"] = @user_agent
        request["Accept"] = "application/x-yaml, application/yaml, text/yaml, */*"
        request
      end

      def parse_response_body(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise APIError.new("Invalid JSON response: #{response.body}", status_code: response.code.to_i)
      end

      def validate_api_status_header(response_data)
        return unless response_data.is_a?(Hash)

        header = response_data["header"]
        return unless header && header["status"]

        status_code = header["status"]["code"]
        return unless status_code && status_code >= 400

        error_message = header["status"]["message"] || "Unknown API error"
        raise APIError.new(error_message, status_code: status_code, response_data: response_data)
      end

      def raise_api_error(response, data)
        error_message = "API request failed"
        if data.is_a?(Hash) && data.dig("header", "status", "message")
          error_message = data.dig("header", "status", "message")
        end
        raise APIError.new(error_message, status_code: response.code.to_i, response_data: data)
      end

      def handle_openapi_response(response)
        case response
        when Net::HTTPSuccess
          {
            content: response.body,
            content_type: response.content_type,
            status: response.code.to_i
          }
        when Net::HTTPUnauthorized
          raise AuthError, "Authentication failed. Check your API key."
        else
          raise APIError.new("API request failed: #{response.code} #{response.message}", status_code: response.code.to_i)
        end
      end

      def raise_ssl_error(error)
        raise Error, "SSL verification failed: #{error.message}. This may be due to system certificate configuration issues."
      end

      def raise_connection_error(error)
        raise Error, "Request failed: #{error.class} - #{error.message}"
      end

      def retryable_api_error?(error)
        error.is_a?(APIError) && error.status_code && RETRYABLE_HTTP_STATUS_CODES.include?(error.status_code)
      end

      def retry_api_error!(error, attempt)
        raise unless retryable_api_error?(error) && attempt < MAX_REQUEST_ATTEMPTS

        sleep(retry_backoff_seconds(attempt))
      end

      def retry_connection_error!(error, attempt)
        raise_connection_error(error) if attempt >= MAX_REQUEST_ATTEMPTS

        sleep(retry_backoff_seconds(attempt))
      end

      def retry_backoff_seconds(attempt)
        RETRY_BASE_DELAY_SECONDS * (2**(attempt - 1))
      end
    end
  end
end
