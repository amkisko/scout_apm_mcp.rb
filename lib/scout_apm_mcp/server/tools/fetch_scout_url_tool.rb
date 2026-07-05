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
        client = get_client

        result = {
          url: url,
          parsed: parsed,
          data: nil
        }

        case parsed[:url_type]
        when :trace
          if parsed[:app_id] && parsed[:trace_id]
            trace_data = client.fetch_trace(parsed[:app_id], parsed[:trace_id])
            result[:data] = {trace: trace_data}

            if include_endpoint && parsed[:endpoint_id]
              begin
                endpoints = client.list_endpoints(parsed[:app_id], range: "7days")
                endpoint_data = endpoints.find { |ep| Helpers.get_endpoint_id(ep) == parsed[:endpoint_id] }

                if endpoint_data
                  result[:data][:endpoint] = endpoint_data
                else
                  result[:data][:endpoint_error] = "Endpoint not found in the last 7 days"
                end
                result[:data][:decoded_endpoint] = parsed[:decoded_endpoint]
              rescue => e
                result[:data][:endpoint_error] = "Failed to fetch endpoint: #{e.message}"
                result[:data][:decoded_endpoint] = parsed[:decoded_endpoint]
              end
            end
          else
            raise "Invalid trace URL: missing app_id or trace_id"
          end
        when :job_trace
          if parsed[:app_id] && parsed[:trace_id]
            trace_data = client.fetch_trace(parsed[:app_id], parsed[:trace_id])
            result[:data] = {trace: trace_data}

            if include_endpoint && parsed[:job_id]
              begin
                jobs = client.list_jobs(parsed[:app_id], range: "7days")
                job_data = jobs.find { |j| Helpers.get_job_id(j) == parsed[:job_id] }

                if job_data
                  result[:data][:job] = job_data
                else
                  result[:data][:job_error] = "Job not found in the last 7 days"
                end
                result[:data][:decoded_job] = parsed[:decoded_job]
              rescue => e
                result[:data][:job_error] = "Failed to fetch job: #{e.message}"
                result[:data][:decoded_job] = parsed[:decoded_job]
              end
            end
          else
            raise "Invalid job trace URL: missing app_id or trace_id"
          end
        when :job
          if parsed[:app_id] && parsed[:job_id]
            jobs = client.list_jobs(parsed[:app_id], range: "7days")
            job_data = jobs.find { |j| Helpers.get_job_id(j) == parsed[:job_id] }

            if job_data
              result[:data] = {
                job: job_data,
                decoded_job: parsed[:decoded_job]
              }
            else
              raise "Job not found in the last 7 days. Try using ListJobsTool with a longer time range."
            end
          else
            raise "Invalid job URL: missing app_id or job_id"
          end
        when :endpoint
          if parsed[:app_id] && parsed[:endpoint_id]
            endpoints = client.list_endpoints(parsed[:app_id], range: "7days")
            endpoint_data = endpoints.find { |ep| Helpers.get_endpoint_id(ep) == parsed[:endpoint_id] }

            if endpoint_data
              result[:data] = {
                endpoint: endpoint_data,
                decoded_endpoint: parsed[:decoded_endpoint]
              }
            else
              raise "Endpoint not found in the last 7 days. Try using ListEndpointsTool with a longer time range."
            end
          else
            raise "Invalid endpoint URL: missing app_id or endpoint_id"
          end
        when :error_group
          if parsed[:app_id] && parsed[:error_id]
            error_data = client.get_error_group(parsed[:app_id], parsed[:error_id])
            result[:data] = {error_group: error_data}
          else
            raise "Invalid error group URL: missing app_id or error_id"
          end
        when :insight
          if parsed[:app_id]
            if parsed[:insight_type]
              insight_data = client.get_insight_by_type(parsed[:app_id], parsed[:insight_type])
              result[:data] = {insight: insight_data, insight_type: parsed[:insight_type]}
            else
              insights_data = client.get_all_insights(parsed[:app_id])
              result[:data] = {insights: insights_data}
            end
          else
            raise "Invalid insight URL: missing app_id"
          end
        when :app
          if parsed[:app_id]
            app_data = client.get_app(parsed[:app_id])
            result[:data] = {app: app_data}
          else
            raise "Invalid app URL: missing app_id"
          end
        when :unknown
          raise "Unknown or unsupported ScoutAPM URL format: #{url}"
        else
          raise "Unable to determine URL type from: #{url}"
        end

        result
      end
    end
  end
end
