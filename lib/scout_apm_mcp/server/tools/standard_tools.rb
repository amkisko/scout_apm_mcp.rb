module ScoutApmMcp
  class Server
    # Applications Tools
    class ListAppsTool < BaseTool
      description <<~DESC
        List all applications accessible with the provided API key.

        Returns an array of applications with details like name, ID, and last reported time.
        Use the app_id from the results to make subsequent API calls.

        Optional filtering:
        - active_since: Only return apps that have reported data since this time (ISO 8601 format)
        - Default behavior: Returns all apps (no filtering by default, but API may filter to last 30 days)

        Example:
        - List all apps: call without parameters
        - List apps active in last 7 days: provide active_since="2025-01-08T00:00:00Z"
      DESC

      arguments do
        optional(:active_since).maybe(:string).description("ISO 8601 datetime string to filter apps active since that time (e.g., 2025-01-08T00:00:00Z)")
      end

      def call(active_since: nil)
        get_client.list_apps(active_since: active_since)
      end
    end

    class GetAppTool < BaseTool
      description "Get application details for a specific application"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
      end

      def call(app_id:)
        get_client.get_app(app_id)
      end
    end

    # Metrics Tools
    class ListMetricsTool < BaseTool
      description "List available metric types for an application"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
      end

      def call(app_id:)
        get_client.list_metrics(app_id)
      end
    end

    class GetMetricTool < BaseTool
      description <<~DESC
        Get time-series data for a specific metric type.

        Available metric types:
        - apdex: Application Performance Index (0-1, higher is better)
        - response_time: Average response time in milliseconds
        - response_time_95th: 95th percentile response time in milliseconds
        - errors: Number of errors
        - throughput: Requests per second
        - queue_time: Time spent in queue in milliseconds

        You can specify time ranges using:
        1. Quick range templates: range="30min", "1day", "3days", "7days", etc.
        2. Explicit times: from and to with ISO 8601 timestamps

        Examples:
        - Get response time for last hour: metric_type="response_time", range="1hr"
        - Get error count for last day: metric_type="errors", range="1day"
        - Get metrics for specific range: metric_type="apdex", from="2025-01-15T10:00:00Z", to="2025-01-15T12:00:00Z"
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:metric_type).filled(:string).description("Metric type: apdex, response_time, response_time_95th, errors, throughput, queue_time")
        optional(:range).maybe(:string).description("Quick time range template: 30min, 60min, 3hrs, 6hrs, 12hrs, 1day, 3days, 7days. If provided, calculates from/to automatically.")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z). Ignored if range is provided.")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z). Used as end point for range if range is provided.")
      end

      def call(app_id:, metric_type:, range: nil, from: nil, to: nil)
        get_client.get_metric(app_id, metric_type, from: from, to: to, range: range)
      end
    end

    # Endpoints Tools
    class ListEndpointsTool < BaseTool
      description <<~DESC
        List all endpoints for an application.

        The API requires timeframe parameters. You can specify time ranges in two ways:
        1. Quick range templates: Use the 'range' parameter (e.g., "30min", "1day", "3days", "7days")
        2. Explicit times: Use 'from' and 'to' parameters with ISO 8601 timestamps

        If neither from/to nor range are provided, defaults to the last 7 days.

        Quick range templates (case-insensitive):
        - "30min" or "30mins" - Last 30 minutes
        - "60min" or "60mins" or "1hr" or "1hour" - Last 60 minutes
        - "3hrs" or "3hours" - Last 3 hours
        - "6hrs" or "6hours" - Last 6 hours
        - "12hrs" or "12hours" - Last 12 hours
        - "1day" or "1days" - Last 24 hours
        - "3days" - Last 3 days
        - "7days" - Last 7 days (default)

        Examples:
        - List endpoints for last 30 minutes: range="30min"
        - List endpoints for last day: range="1day"
        - List endpoints for a specific range: from="2025-01-15T10:00:00Z", to="2025-01-15T12:00:00Z"
        - List endpoints from a specific time to now: from="2025-01-15T10:00:00Z"
        - List endpoints for 1 day ending at specific time: range="1day", to="2025-01-15T12:00:00Z"

        Pagination (returns endpoints plus count/total_count/has_more instead of a bare array):
        - sort_by: time_consumed, response_time, throughput, or error_rate (descending)
        - limit: page size
        - offset: skip count for pagination
        Supplying any of sort_by, limit, or offset switches to the paginated response shape.
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:range).maybe(:string).description("Quick time range template: 30min, 60min, 3hrs, 6hrs, 12hrs, 1day, 3days, 7days. If provided, calculates from/to automatically.")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z). Ignored if range is provided.")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z). Used as end point for range if range is provided, otherwise defaults to now.")
        optional(:sort_by).maybe(:string).description("Sort paginated listing by: time_consumed, response_time, throughput, error_rate")
        optional(:limit).maybe(:integer).description("Maximum endpoints to return (paginated listing)")
        optional(:offset).maybe(:integer).description("Number of endpoints to skip (paginated listing)")
      end

      def call(app_id:, range: nil, from: nil, to: nil, sort_by: nil, limit: nil, offset: nil)
        get_client.list_endpoints(app_id, from: from, to: to, range: range, sort_by: sort_by, limit: limit, offset: offset)
      end
    end

    class GetEndpointMetricsTool < BaseTool
      description <<~DESC
        Get metric data for a specific endpoint.

        Available metric types:
        - apdex: Application Performance Index (0-1, higher is better)
        - response_time: Average response time in milliseconds
        - response_time_95th: 95th percentile response time in milliseconds
        - errors: Number of errors
        - throughput: Requests per second
        - queue_time: Time spent in queue in milliseconds

        You can specify time ranges using:
        1. Quick range templates: range="30min", "1day", "3days", "7days", etc.
        2. Explicit times: from and to with ISO 8601 timestamps

        Returns time-series data points for the specified metric type.

        Examples:
        - Get response time for last hour: metric_type="response_time", range="1hr"
        - Get error count for last day: metric_type="errors", range="1day"
        - Get metrics for specific range: metric_type="apdex", from="2025-01-15T10:00:00Z", to="2025-01-15T12:00:00Z"
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:endpoint_id).filled(:string).description("Endpoint ID (base64 URL-encoded). Extract from ScoutAPM URLs or use ParseScoutURLTool.")
        required(:metric_type).filled(:string).description("Metric type: apdex, response_time, response_time_95th, errors, throughput, queue_time")
        optional(:range).maybe(:string).description("Quick time range template: 30min, 60min, 3hrs, 6hrs, 12hrs, 1day, 3days, 7days. If provided, calculates from/to automatically.")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z). Ignored if range is provided.")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z). Used as end point for range if range is provided.")
      end

      def call(app_id:, endpoint_id:, metric_type:, range: nil, from: nil, to: nil)
        get_client.get_endpoint_metrics(app_id, endpoint_id, metric_type, from: from, to: to, range: range)
      end
    end

    class ListEndpointTracesTool < BaseTool
      description <<~DESC
        List traces for a specific endpoint (max 100, within 7 days).

        Traces are individual request executions that can be analyzed for performance issues.
        Returns up to 100 traces for the specified endpoint within the last 7 days.

        You can specify time ranges using:
        1. Quick range templates: range="30min", "1day", "3days", "7days", etc.
        2. Explicit times: from and to with ISO 8601 timestamps

        Time range constraints:
        - If from is provided, it must be within the last 7 days
        - Maximum 100 traces returned per request
        - Use the trace_id from results with FetchTraceTool for detailed analysis

        Examples:
        - List traces from last hour: range="1hr"
        - List traces from last day: range="1day"
        - List traces for specific range: from="2025-01-15T10:00:00Z", to="2025-01-15T12:00:00Z"
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:endpoint_id).filled(:string).description("Endpoint ID (base64 URL-encoded). Extract from ScoutAPM URLs or use ParseScoutURLTool.")
        optional(:range).maybe(:string).description("Quick time range template: 30min, 60min, 3hrs, 6hrs, 12hrs, 1day, 3days, 7days. If provided, calculates from/to automatically.")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z). Must be within last 7 days. Ignored if range is provided.")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z). Used as end point for range if range is provided.")
      end

      def call(app_id:, endpoint_id:, range: nil, from: nil, to: nil)
        get_client.list_endpoint_traces(app_id, endpoint_id, from: from, to: to, range: range)
      end
    end

    class ListJobsTool < BaseTool
      description <<~DESC
        List background jobs for an application with performance metrics (throughput, execution time, etc.).

        Time range: same as ListEndpointsTool — use range and/or from/to. If none are given, defaults to the last 7 days.

        Each job includes a `job_id` (base64) for ListJobMetricsTool, GetJobMetricsTool, and ListJobTracesTool.
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:range).maybe(:string).description("Quick time range: 30min, 60min, 3hrs, 6hrs, 12hrs, 1day, 3days, 7days")
        optional(:from).maybe(:string).description("Start time ISO 8601. Ignored if range is provided.")
        optional(:to).maybe(:string).description("End time ISO 8601; anchor for range if range is provided.")
      end

      def call(app_id:, range: nil, from: nil, to: nil)
        get_client.list_jobs(app_id, from: from, to: to, range: range)
      end
    end

    class ListJobMetricsTool < BaseTool
      description "List available metric types for a specific background job (throughput, execution_time, latency, errors, allocations)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:job_id).filled(:string).description("Job ID (base64 URL-encoded) from list_jobs results")
      end

      def call(app_id:, job_id:)
        get_client.list_job_metrics(app_id, job_id)
      end
    end

    class GetJobMetricsTool < BaseTool
      description <<~DESC
        Get time-series data for a background job metric.

        Metric types: throughput, execution_time, latency, errors, allocations (not the same set as HTTP endpoint metrics).

        Use range or explicit from/to, same as GetEndpointMetricsTool.
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:job_id).filled(:string).description("Job ID (base64 URL-encoded)")
        required(:metric_type).filled(:string).description("Job metric: throughput, execution_time, latency, errors, allocations")
        optional(:range).maybe(:string).description("Quick time range template")
        optional(:from).maybe(:string).description("Start time ISO 8601. Ignored if range is provided.")
        optional(:to).maybe(:string).description("End time ISO 8601.")
      end

      def call(app_id:, job_id:, metric_type:, range: nil, from: nil, to: nil)
        get_client.get_job_metrics(app_id, job_id, metric_type, from: from, to: to, range: range)
      end
    end

    class ListJobTracesTool < BaseTool
      description <<~DESC
        List traces for a background job (max 100, within 7 days). Same time constraints as ListEndpointTracesTool.

        Use FetchTraceTool with a trace id from results for full span detail.
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:job_id).filled(:string).description("Job ID (base64 URL-encoded)")
        optional(:range).maybe(:string).description("Quick time range template")
        optional(:from).maybe(:string).description("Start time ISO 8601; must be within last 7 days if used with to.")
        optional(:to).maybe(:string).description("End time ISO 8601.")
      end

      def call(app_id:, job_id:, range: nil, from: nil, to: nil)
        get_client.list_job_traces(app_id, job_id, from: from, to: to, range: range)
      end
    end

    class FetchTraceTool < BaseTool
      description "Fetch detailed trace information from ScoutAPM API"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:trace_id).filled(:integer).description("Trace identifier")
        optional(:include_endpoint).filled(:bool).description("Also fetch endpoint details for context (default: false)")
      end

      def call(app_id:, trace_id:, include_endpoint: false)
        client = get_client
        result = {
          trace: client.fetch_trace(app_id, trace_id)
        }

        if include_endpoint
          trace_data = result[:trace]
          if trace_data.is_a?(Hash) && trace_data["metric_name"]
            result[:trace_metric_name] = trace_data["metric_name"]
          end
        end

        result
      end
    end

    # Errors Tools
    class ListErrorGroupsTool < BaseTool
      description "List error groups for an application (max 100, within 30 days)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
        optional(:endpoint).maybe(:string).description("Base64 URL-encoded endpoint filter (optional)")
      end

      def call(app_id:, from: nil, to: nil, endpoint: nil)
        get_client.list_error_groups(app_id, from: from, to: to, endpoint: endpoint)
      end
    end

    class GetErrorGroupTool < BaseTool
      description "Get details for a specific error group"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:error_id).filled(:integer).description("Error group identifier")
      end

      def call(app_id:, error_id:)
        get_client.get_error_group(app_id, error_id)
      end
    end

    class GetErrorGroupErrorsTool < BaseTool
      description "Get individual errors within an error group (max 100)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:error_id).filled(:integer).description("Error group identifier")
      end

      def call(app_id:, error_id:)
        get_client.get_error_group_errors(app_id, error_id)
      end
    end

    # Anomaly Tools
    class ListAnomalyEventsTool < BaseTool
      description <<~DESC
        List anomaly events for an application (max 100, within 30 days).

        Optional filters:
        - state: open, closed, or all (default on API side is all)
        - metric: metric name such as response_time or error_rate
        - endpoint: exact endpoint name match

        Time range: use range and/or from/to (same templates as ListEndpointsTool).
      DESC

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:range).maybe(:string).description("Quick time range template: 30min, 60min, 3hrs, 6hrs, 12hrs, 1day, 3days, 7days")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format")
        optional(:to).maybe(:string).description("End time in ISO 8601 format")
        optional(:state).maybe(:string).description("Filter by state: open, closed, all")
        optional(:metric).maybe(:string).description("Filter by metric name")
        optional(:endpoint).maybe(:string).description("Filter by endpoint name (exact match)")
      end

      def call(app_id:, range: nil, from: nil, to: nil, state: nil, metric: nil, endpoint: nil)
        get_client.list_anomaly_events(
          app_id,
          from: from,
          to: to,
          range: range,
          state: state,
          metric: metric,
          endpoint: endpoint
        )
      end
    end

    class GetAnomalyEventTool < BaseTool
      description "Get details for a specific anomaly event, including smart monitor and deploy context"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:anomaly_event_id).filled(:integer).description("Anomaly event identifier")
      end

      def call(app_id:, anomaly_event_id:)
        get_client.get_anomaly_event(app_id, anomaly_event_id)
      end
    end

    # Insights Tools
    class GetAllInsightsTool < BaseTool
      description "Get all insight types for an application (cached for 5 minutes)"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:limit).maybe(:integer).description("Maximum number of items per insight type (default: 20)")
      end

      def call(app_id:, limit: nil)
        get_client.get_all_insights(app_id, limit: limit)
      end
    end

    class GetInsightByTypeTool < BaseTool
      description "Get data for a specific insight type"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:insight_type).filled(:string).description("Insight type: n_plus_one, memory_bloat, slow_query")
        optional(:limit).maybe(:integer).description("Maximum number of items (default: 20)")
      end

      def call(app_id:, insight_type:, limit: nil)
        get_client.get_insight_by_type(app_id, insight_type, limit: limit)
      end
    end

    class GetInsightsHistoryTool < BaseTool
      description "Get historical insights data with cursor-based pagination"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
        optional(:limit).maybe(:integer).description("Maximum number of items per page (default: 10)")
        optional(:pagination_cursor).maybe(:integer).description("Cursor for pagination (insight ID)")
        optional(:pagination_direction).maybe(:string).description("Pagination direction: forward, backward (default: forward)")
        optional(:pagination_page).maybe(:integer).description("Page number for pagination (default: 1)")
      end

      def call(app_id:, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
        get_client.get_insights_history(
          app_id,
          from: from,
          to: to,
          limit: limit,
          pagination_cursor: pagination_cursor,
          pagination_direction: pagination_direction,
          pagination_page: pagination_page
        )
      end
    end

    class GetInsightsHistoryByTypeTool < BaseTool
      description "Get historical insights data filtered by insight type with cursor-based pagination"

      arguments do
        required(:app_id).filled(:integer).description("ScoutAPM application ID")
        required(:insight_type).filled(:string).description("Insight type: n_plus_one, memory_bloat, slow_query")
        optional(:from).maybe(:string).description("Start time in ISO 8601 format (e.g., 2025-11-17T15:25:35Z)")
        optional(:to).maybe(:string).description("End time in ISO 8601 format (e.g., 2025-11-18T15:25:35Z)")
        optional(:limit).maybe(:integer).description("Maximum number of items per page (default: 10)")
        optional(:pagination_cursor).maybe(:integer).description("Cursor for pagination (insight ID)")
        optional(:pagination_direction).maybe(:string).description("Pagination direction: forward, backward (default: forward)")
        optional(:pagination_page).maybe(:integer).description("Page number for pagination (default: 1)")
      end

      def call(app_id:, insight_type:, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
        get_client.get_insights_history_by_type(
          app_id,
          insight_type,
          from: from,
          to: to,
          limit: limit,
          pagination_cursor: pagination_cursor,
          pagination_direction: pagination_direction,
          pagination_page: pagination_page
        )
      end
    end
  end
end
