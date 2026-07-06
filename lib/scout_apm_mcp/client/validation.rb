module ScoutApmMcp
  class Client
    module Validation
      private

      def validate_insight_type(insight_type)
        return if VALID_INSIGHTS.include?(insight_type)

        raise ArgumentError, "Invalid insight_type. Must be one of: #{VALID_INSIGHTS.join(", ")}"
      end

      def validate_metric_params(metric_type, from, to)
        unless VALID_METRICS.include?(metric_type)
          raise ArgumentError, "Invalid metric_type. Must be one of: #{VALID_METRICS.join(", ")}"
        end
        validate_time_range(from, to) if from && to
      end

      def validate_job_metric_params(metric_type, from, to)
        unless VALID_JOB_METRICS.include?(metric_type)
          raise ArgumentError, "Invalid metric_type. Must be one of: #{VALID_JOB_METRICS.join(", ")}"
        end
        validate_time_range(from, to) if from && to
      end

      def validate_time_range(from, to)
        return unless from && to

        from_time = Helpers.parse_time(from)
        to_time = Helpers.parse_time(to)

        if from_time >= to_time
          raise ArgumentError, "from_time must be before to_time"
        end

        max_duration = 14 * 24 * 60 * 60
        if (to_time - from_time) > max_duration
          raise ArgumentError, "Time range cannot exceed 2 weeks"
        end
      end

      def resolve_range_times(from:, to:, range:)
        return {from: from, to: to} unless range

        Helpers.calculate_range(range: range, to: to)
      end

      def resolve_listing_time_range(from:, to:, range:, default_range: "7days")
        range = default_range if listing_range_unset?(from, to, range)
        times = resolve_range_times(from: from, to: to, range: range)
        from, to = normalize_listing_bounds(times[:from], times[:to])
        validate_time_range(from, to) if from && to
        {from: from, to: to}
      end

      def listing_range_unset?(from, to, range)
        from.nil? && to.nil? && range.nil?
      end

      def normalize_listing_bounds(from, to)
        from = Helpers.calculate_range(range: "7days", to: to)[:from] if from.nil? && to
        to = Helpers.format_time(Time.now.utc) if from && to.nil?
        [from, to]
      end

      def validate_trace_time_range(from, to)
        validate_time_range(from, to) if from && to
        return unless from && to

        from_time = Helpers.parse_time(from)
        seven_days_ago = Time.now.utc - (7 * 24 * 60 * 60)
        if from_time < seven_days_ago
          raise ArgumentError, "from_time cannot be older than 7 days"
        end
      end

      def validate_sort_by!(sort_by)
        return if sort_by.nil? || VALID_ENDPOINT_SORT_BY.include?(sort_by)

        raise ArgumentError, "Invalid sort_by. Must be one of: #{VALID_ENDPOINT_SORT_BY.join(", ")}"
      end

      def validate_anomaly_state!(state)
        return if state.nil? || VALID_ANOMALY_STATES.include?(state)

        raise ArgumentError, "Invalid state. Must be one of: #{VALID_ANOMALY_STATES.join(", ")}"
      end
    end
  end
end
