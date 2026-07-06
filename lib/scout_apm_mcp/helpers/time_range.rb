module ScoutApmMcp
  module Helpers
    module TimeRange
      def format_time(time)
        time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      end

      def parse_time(time_str)
        normalized = time_str.sub(/Z\z/i, "+00:00")
        Time.parse(normalized).utc
      end

      def make_duration(from_str, to_str)
        {
          start: parse_time(from_str),
          end: parse_time(to_str)
        }
      end

      def parse_range(range_str)
        return nil if range_str.nil? || range_str.empty?

        normalized = range_str.downcase.strip.gsub(/\s+/, "")
        match = normalized.match(/\A(\d+)(min|mins?|hr|hrs?|hour|hours|day|days)\z/)
        raise_invalid_range!(range_str) unless match

        range_seconds(match[1].to_i, match[2])
      end

      def range_seconds(value, unit)
        case unit
        when /^min/
          value * 60
        when /^hr/, /^hour/
          value * 60 * 60
        when /^day/
          value * 24 * 60 * 60
        else
          raise ArgumentError, "Unknown time unit: #{unit}"
        end
      end

      def raise_invalid_range!(range_str)
        valid_ranges = %w[30min 60min 3hrs 6hrs 12hrs 1day 3days 7days]
        raise ArgumentError, "Invalid range format: #{range_str}. Valid formats: #{valid_ranges.join(", ")}"
      end

      def calculate_range(range:, to: nil)
        return {from: nil, to: to} if range.nil? || range.to_s.strip.empty?

        range_str = range.to_s.strip
        range_str = "#{range_str}days" if range_str.match?(/\A\d+\z/)

        end_time = to ? parse_time(to) : Time.now.utc
        duration_seconds = parse_range(range_str)
        start_time = end_time - duration_seconds

        {
          from: format_time(start_time),
          to: format_time(end_time)
        }
      end
    end
  end
end
