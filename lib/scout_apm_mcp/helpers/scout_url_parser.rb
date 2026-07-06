module ScoutApmMcp
  module Helpers
    module ScoutUrlParser
      def parse_scout_url(url)
        uri = URI.parse(url)
        path_parts = uri.path.split("/").reject(&:empty?)
        result = {}
        app_index = path_parts.index("apps")

        return result unless app_index

        result[:app_id] = path_parts[app_index + 1].to_i
        assign_url_type(path_parts, result)
        attach_query_params(uri, result)
        attach_decoded_endpoint(result)
        result
      end

      private

      def assign_url_type(path_parts, result)
        return assign_trace_url(path_parts, result) if trace_url?(path_parts)
        return assign_job_url(path_parts, result) if path_parts.include?("jobs")
        return assign_endpoint_url(path_parts, result) if path_parts.include?("endpoints")
        return assign_error_group_url(path_parts, result) if path_parts.include?("error_groups")
        return assign_insight_url(path_parts, result) if path_parts.include?("insights")

        result[:url_type] = app_url?(path_parts) ? :app : :unknown
      end

      def trace_url?(path_parts)
        path_parts.include?("trace") && path_parts.include?("endpoints")
      end

      def app_url?(path_parts)
        path_parts.length == 2 && path_parts[0] == "apps"
      end

      def assign_trace_url(path_parts, result)
        result[:url_type] = :trace
        endpoints_index = path_parts.index("endpoints")
        trace_index = path_parts.index("trace")
        return unless endpoints_index && trace_index

        result[:endpoint_id] = path_parts[endpoints_index + 1]
        result[:trace_id] = path_parts[trace_index + 1].to_i
      end

      def assign_job_url(path_parts, result)
        jobs_index = path_parts.index("jobs")
        return unless jobs_index && path_parts[jobs_index + 1]

        result[:job_id] = path_parts[jobs_index + 1]
        result[:url_type] = job_url_type(path_parts)
        assign_job_trace_id(path_parts, result) if result[:url_type] == :job_trace
        result[:decoded_job] = decode_endpoint_id(result[:job_id])
      end

      def job_url_type(path_parts)
        return :job unless path_parts.include?("trace")

        trace_index = path_parts.index("trace")
        (trace_index && path_parts[trace_index + 1]) ? :job_trace : :job
      end

      def assign_job_trace_id(path_parts, result)
        trace_index = path_parts.index("trace")
        result[:trace_id] = path_parts[trace_index + 1].to_i if trace_index
      end

      def assign_endpoint_url(path_parts, result)
        result[:url_type] = :endpoint
        endpoints_index = path_parts.index("endpoints")
        result[:endpoint_id] = path_parts[endpoints_index + 1] if endpoints_index
      end

      def assign_error_group_url(path_parts, result)
        result[:url_type] = :error_group
        error_groups_index = path_parts.index("error_groups")
        result[:error_id] = path_parts[error_groups_index + 1].to_i if error_groups_index
      end

      def assign_insight_url(path_parts, result)
        result[:url_type] = :insight
        insights_index = path_parts.index("insights")
        return unless insights_index && path_parts.length > insights_index + 1

        result[:insight_type] = path_parts[insights_index + 1]
      end

      def attach_query_params(uri, result)
        return unless uri.query

        result[:query_params] = URI.decode_www_form(uri.query).to_h
      end

      def attach_decoded_endpoint(result)
        return unless result[:endpoint_id]

        result[:decoded_endpoint] = decode_endpoint_id(result[:endpoint_id])
      end
    end
  end
end
