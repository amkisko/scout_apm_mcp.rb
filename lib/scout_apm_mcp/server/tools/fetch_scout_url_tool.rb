module ScoutApmMcp
  class Server
    class FetchScoutURLTool < BaseTool
      description <<~DESC
        Fetch data from a ScoutAPM URL by automatically detecting the resource type and fetching the appropriate data.

        This tool automatically parses ScoutAPM URLs and fetches the corresponding data.
        Supported URL types:
        - Endpoint URLs: /apps/{app_id}/endpoints/{endpoint_id} (fetches from endpoint list)
        - Job URLs: /apps/{app_id}/jobs/{job_id} (fetches from job list)
        - Trace URLs: /apps/{app_id}/endpoints/{endpoint_id}/trace/{trace_id}
        - Job trace URLs: /apps/{app_id}/jobs/{job_id}/trace/{trace_id}
        - Error group URLs: /apps/{app_id}/error_groups/{error_id}
        - Insight URLs: /apps/{app_id}/insights or /apps/{app_id}/insights/{insight_type}
        - App URLs: /apps/{app_id}

        Examples:
        - https://scoutapm.com/apps/123/endpoints/ABC123... (endpoint)
        - https://scoutapm.com/apps/123/endpoints/ABC123.../trace/456 (trace)
        - https://scoutapm.com/apps/123/error_groups/789 (error group)

        For endpoint or job trace URLs, set include_endpoint=true to also fetch endpoint or job summary from the last 7 days.
      DESC

      arguments do
        required(:url).filled(:string).description("Full ScoutAPM URL")
        optional(:include_endpoint).filled(:bool).description("For trace URLs, also fetch endpoint or job context from recent list (default: false)")
      end

      def call(url:, include_endpoint: false)
        parsed = Helpers.parse_scout_url(url)
        {
          url: url,
          parsed: parsed,
          data: fetch_url_data(parsed, include_endpoint: include_endpoint)
        }
      end

      private

      def fetch_url_data(parsed, include_endpoint:)
        case parsed[:url_type]
        when :trace then fetch_trace_data(parsed, include_endpoint: include_endpoint)
        when :job_trace then fetch_job_trace_data(parsed, include_endpoint: include_endpoint)
        when :job then fetch_job_data(parsed)
        when :endpoint then fetch_endpoint_data(parsed)
        when :error_group then fetch_error_group_data(parsed)
        when :insight then fetch_insight_data(parsed)
        when :app then fetch_app_data(parsed)
        when :unknown then raise "Unknown or unsupported ScoutAPM URL format"
        else raise "Unable to determine URL type"
        end
      end

      def fetch_trace_data(parsed, include_endpoint:)
        require_ids!(parsed, :app_id, :trace_id, "trace URL")
        data = {trace: get_client.fetch_trace(parsed[:app_id], parsed[:trace_id])}
        attach_endpoint_context(data, parsed) if include_endpoint && parsed[:endpoint_id]
        data
      end

      def fetch_job_trace_data(parsed, include_endpoint:)
        require_ids!(parsed, :app_id, :trace_id, "job trace URL")
        data = {trace: get_client.fetch_trace(parsed[:app_id], parsed[:trace_id])}
        attach_job_context(data, parsed) if include_endpoint && parsed[:job_id]
        data
      end

      def fetch_job_data(parsed)
        require_ids!(parsed, :app_id, :job_id, "job URL")
        job_data = find_recent_job(parsed[:app_id], parsed[:job_id])
        raise "Job not found in the last 7 days. Try using ListJobsTool with a longer time range." unless job_data

        {job: job_data, decoded_job: parsed[:decoded_job]}
      end

      def fetch_endpoint_data(parsed)
        require_ids!(parsed, :app_id, :endpoint_id, "endpoint URL")
        endpoint_data = find_recent_endpoint(parsed[:app_id], parsed[:endpoint_id])
        unless endpoint_data
          raise "Endpoint not found in the last 7 days. Try using ListEndpointsTool with a longer time range."
        end

        {endpoint: endpoint_data, decoded_endpoint: parsed[:decoded_endpoint]}
      end

      def fetch_error_group_data(parsed)
        require_ids!(parsed, :app_id, :error_id, "error group URL")
        {error_group: get_client.get_error_group(parsed[:app_id], parsed[:error_id])}
      end

      def fetch_insight_data(parsed)
        raise "Invalid insight URL: missing app_id" unless parsed[:app_id]

        if parsed[:insight_type]
          {
            insight: get_client.get_insight_by_type(parsed[:app_id], parsed[:insight_type]),
            insight_type: parsed[:insight_type]
          }
        else
          {insights: get_client.get_all_insights(parsed[:app_id])}
        end
      end

      def fetch_app_data(parsed)
        raise "Invalid app URL: missing app_id" unless parsed[:app_id]

        {app: get_client.get_app(parsed[:app_id])}
      end

      def attach_endpoint_context(data, parsed)
        endpoint_data = find_recent_endpoint(parsed[:app_id], parsed[:endpoint_id])
        if endpoint_data
          data[:endpoint] = endpoint_data
        else
          data[:endpoint_error] = "Endpoint not found in the last 7 days"
        end
        data[:decoded_endpoint] = parsed[:decoded_endpoint]
      rescue => error
        data[:endpoint_error] = "Failed to fetch endpoint: #{error.message}"
        data[:decoded_endpoint] = parsed[:decoded_endpoint]
      end

      def attach_job_context(data, parsed)
        job_data = find_recent_job(parsed[:app_id], parsed[:job_id])
        if job_data
          data[:job] = job_data
        else
          data[:job_error] = "Job not found in the last 7 days"
        end
        data[:decoded_job] = parsed[:decoded_job]
      rescue => error
        data[:job_error] = "Failed to fetch job: #{error.message}"
        data[:decoded_job] = parsed[:decoded_job]
      end

      def find_recent_endpoint(app_id, endpoint_id)
        endpoints = get_client.list_endpoints(app_id, range: "7days")
        endpoints.find { |endpoint| Helpers.get_endpoint_id(endpoint) == endpoint_id }
      end

      def find_recent_job(app_id, job_id)
        jobs = get_client.list_jobs(app_id, range: "7days")
        jobs.find { |job| Helpers.get_job_id(job) == job_id }
      end

      def require_ids!(parsed, *keys, label)
        missing = keys.reject { |key| parsed[key] }
        return if missing.empty?

        raise "Invalid #{label}: missing #{missing.join(" or ")}"
      end
    end
  end
end
