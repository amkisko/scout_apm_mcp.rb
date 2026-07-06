module ScoutApmMcp
  class Client
    module QueryParams
      private

      def build_query_string(from: nil, to: nil)
        encode_query_params("from" => from, "to" => to)
      end

      def encode_query_params(params)
        filtered = params.each_with_object({}) do |(key, value), hash|
          hash[key] = value unless value.nil?
        end
        return nil if filtered.empty?

        URI.encode_www_form(filtered)
      end

      def assign_query(uri, **params)
        query = encode_query_params(params.transform_keys(&:to_s))
        uri.query = query if query
      end

      def api_uri(*path_segments)
        uri = URI(@api_base)
        uri.path = File.join(uri.path, *path_segments.map(&:to_s))
        uri
      end
    end
  end
end
