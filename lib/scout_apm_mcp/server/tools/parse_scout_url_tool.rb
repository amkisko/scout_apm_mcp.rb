module ScoutApmMcp
  class Server
    # Utility Tools
    class ParseScoutURLTool < BaseTool
      description <<~DESC
        Parse a ScoutAPM URL and extract resource information (app_id, endpoint_id, trace_id, etc.).

        This tool extracts structured information from ScoutAPM URLs without making API calls.
        Useful for extracting IDs before making other API requests.

        Returns a hash with:
        - url_type: :endpoint, :trace, :job, :job_trace, :error_group, :insight, :app, or :unknown
        - app_id: Application ID (integer)
        - endpoint_id: Base64 URL-encoded endpoint ID (if present)
        - job_id: Base64 URL-encoded job ID (if present)
        - trace_id: Trace ID (if present)
        - decoded_job: Human-readable queue/job name (if job_id present)
        - error_id: Error group ID (if present)
        - insight_type: Insight type (if present)
        - decoded_endpoint: Human-readable endpoint path (if endpoint_id present)

        Example:
        - Input: "https://scoutapm.com/apps/123/endpoints/ABC123.../trace/456"
        - Output: {url_type: :trace, app_id: 123, endpoint_id: "ABC123...", trace_id: 456, decoded_endpoint: "Controller/Action"}
      DESC

      arguments do
        required(:url).filled(:string).description("Full ScoutAPM URL")
      end

      def call(url:)
        Helpers.parse_scout_url(url)
      end
    end
  end
end
