module ScoutApmMcp
  class Client
    module Api
      module Apps
        def list_apps(active_since: nil)
          uri = URI("#{@api_base}/apps")
          response = make_request(uri)
          apps = response.dig("results", "apps") || []
          return apps unless active_since

          active_time = Helpers.parse_time(active_since)
          apps.select do |app|
            reported_at = app["last_reported_at"]
            reported_at && !reported_at.empty? && Helpers.parse_time(reported_at) >= active_time
          end
        end

        def get_app(app_id)
          uri = URI("#{@api_base}/apps/#{app_id}")
          response = make_request(uri)
          response.dig("results", "app") || {}
        end
      end

      module Metrics
        def list_metrics(app_id)
          uri = URI("#{@api_base}/apps/#{app_id}/metrics")
          response = make_request(uri)
          response.dig("results", "availableMetrics") || []
        end

        def get_metric(app_id, metric_type, from: nil, to: nil, range: nil)
          times = resolve_range_times(from: from, to: to, range: range)
          validate_metric_params(metric_type, times[:from], times[:to])
          uri = URI("#{@api_base}/apps/#{app_id}/metrics/#{metric_type}")
          assign_query(uri, from: times[:from], to: times[:to])
          response = make_request(uri)
          response.dig("results", "series") || {}
        end
      end

      module Endpoints
        def list_endpoints(app_id, from: nil, to: nil, range: nil, sort_by: nil, limit: nil, offset: nil)
          times = resolve_listing_time_range(from: from, to: to, range: range)
          validate_sort_by!(sort_by)

          uri = URI("#{@api_base}/apps/#{app_id}/endpoints")
          assign_query(uri, from: times[:from], to: times[:to], sort_by: sort_by, limit: limit, offset: offset)
          response = make_request(uri)
          endpoint_listing_results(response, sort_by: sort_by, limit: limit, offset: offset)
        end

        def get_endpoint_metrics(app_id, endpoint_id, metric_type, from: nil, to: nil, range: nil)
          times = resolve_range_times(from: from, to: to, range: range)
          validate_metric_params(metric_type, times[:from], times[:to])
          uri = api_uri("apps", app_id, "endpoints", endpoint_id, "metrics", metric_type)
          assign_query(uri, from: times[:from], to: times[:to])
          response = make_request(uri)
          series = response.dig("results", "series") || {}
          series[metric_type] || []
        end

        def list_endpoint_traces(app_id, endpoint_id, from: nil, to: nil, range: nil)
          times = resolve_range_times(from: from, to: to, range: range)
          validate_trace_time_range(times[:from], times[:to])
          uri = api_uri("apps", app_id, "endpoints", endpoint_id, "traces")
          assign_query(uri, from: times[:from], to: times[:to])
          response = make_request(uri)
          response.dig("results", "traces") || []
        end

        private

        def endpoint_listing_results(response, sort_by:, limit:, offset:)
          results = response["results"]
          paginated = !sort_by.nil? || !limit.nil? || !offset.nil?
          paginated ? (results || {}) : (results || [])
        end
      end

      module Jobs
        def list_jobs(app_id, from: nil, to: nil, range: nil)
          times = resolve_listing_time_range(from: from, to: to, range: range)
          uri = URI("#{@api_base}/apps/#{app_id}/jobs")
          assign_query(uri, from: times[:from], to: times[:to])
          response = make_request(uri)
          response["results"] || []
        end

        def list_job_metrics(app_id, job_id)
          uri = api_uri("apps", app_id, "jobs", job_id, "metrics")
          response = make_request(uri)
          response.dig("results", "availableMetrics") || []
        end

        def get_job_metrics(app_id, job_id, metric_type, from: nil, to: nil, range: nil)
          times = resolve_range_times(from: from, to: to, range: range)
          validate_job_metric_params(metric_type, times[:from], times[:to])
          uri = api_uri("apps", app_id, "jobs", job_id, "metrics", metric_type)
          assign_query(uri, from: times[:from], to: times[:to])
          response = make_request(uri)
          series = response.dig("results", "series") || {}
          series[metric_type] || []
        end

        def list_job_traces(app_id, job_id, from: nil, to: nil, range: nil)
          times = resolve_range_times(from: from, to: to, range: range)
          validate_trace_time_range(times[:from], times[:to])
          uri = api_uri("apps", app_id, "jobs", job_id, "traces")
          assign_query(uri, from: times[:from], to: times[:to])
          response = make_request(uri)
          response.dig("results", "traces") || []
        end
      end

      module Traces
        def fetch_trace(app_id, trace_id)
          uri = URI("#{@api_base}/apps/#{app_id}/traces/#{trace_id}")
          response = make_request(uri)
          response.dig("results", "trace") || {}
        end
      end

      module ErrorGroups
        def list_error_groups(app_id, from: nil, to: nil, endpoint: nil)
          validate_time_range(from, to) if from && to
          uri = URI("#{@api_base}/apps/#{app_id}/error_groups")
          assign_query(uri, from: from, to: to, endpoint: endpoint)
          response = make_request(uri)
          response.dig("results", "error_groups") || []
        end

        def get_error_group(app_id, error_id)
          uri = URI("#{@api_base}/apps/#{app_id}/error_groups/#{error_id}")
          response = make_request(uri)
          response.dig("results", "error_group") || {}
        end

        def get_error_group_errors(app_id, error_id)
          uri = URI("#{@api_base}/apps/#{app_id}/error_groups/#{error_id}/errors")
          response = make_request(uri)
          response.dig("results", "errors") || []
        end
      end

      module AnomalyEvents
        def list_anomaly_events(app_id, from: nil, to: nil, range: nil, state: nil, metric: nil, endpoint: nil)
          times = resolve_range_times(from: from, to: to, range: range)
          validate_time_range(times[:from], times[:to]) if times[:from] && times[:to]
          validate_anomaly_state!(state)

          uri = URI("#{@api_base}/apps/#{app_id}/anomaly_events")
          assign_query(uri, from: times[:from], to: times[:to], state: state, metric: metric, endpoint: endpoint)
          response = make_request(uri)
          response.dig("results", "anomaly_events") || []
        end

        def get_anomaly_event(app_id, anomaly_event_id)
          uri = URI("#{@api_base}/apps/#{app_id}/anomaly_events/#{anomaly_event_id}")
          response = make_request(uri)
          response.dig("results", "anomaly_event") || {}
        end
      end

      module Insights
        def get_all_insights(app_id, limit: nil)
          uri = URI("#{@api_base}/apps/#{app_id}/insights")
          assign_query(uri, limit: limit)
          response = make_request(uri)
          response["results"] || {}
        end

        def get_insight_by_type(app_id, insight_type, limit: nil)
          validate_insight_type(insight_type)
          uri = URI("#{@api_base}/apps/#{app_id}/insights/#{insight_type}")
          assign_query(uri, limit: limit)
          response = make_request(uri)
          response["results"] || {}
        end

        def get_insights_history(app_id, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
          uri = URI("#{@api_base}/apps/#{app_id}/insights/history")
          assign_query(
            uri,
            from: from,
            to: to,
            limit: limit,
            pagination_cursor: pagination_cursor,
            pagination_direction: pagination_direction,
            pagination_page: pagination_page
          )
          response = make_request(uri)
          response["results"] || {}
        end

        def get_insights_history_by_type(app_id, insight_type, from: nil, to: nil, limit: nil, pagination_cursor: nil, pagination_direction: nil, pagination_page: nil)
          validate_insight_type(insight_type)
          uri = URI("#{@api_base}/apps/#{app_id}/insights/history/#{insight_type}")
          assign_query(
            uri,
            from: from,
            to: to,
            limit: limit,
            pagination_cursor: pagination_cursor,
            pagination_direction: pagination_direction,
            pagination_page: pagination_page
          )
          response = make_request(uri)
          response["results"] || {}
        end
      end

      module OpenApi
        def fetch_openapi_schema
          uri = URI("https://scoutapm.com/api/v0/openapi.yaml")
          fetch_openapi_schema_response(uri)
        end
      end
    end
  end
end
