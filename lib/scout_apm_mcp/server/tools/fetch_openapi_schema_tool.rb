module ScoutApmMcp
  class Server
    class FetchOpenAPISchemaTool < BaseTool
      description "Fetch the ScoutAPM OpenAPI schema from the API and optionally validate it"

      arguments do
        optional(:validate).filled(:bool).description("Validate the schema structure (default: false)")
        optional(:compare_with_local).filled(:bool).description("Compare with local schema file (tmp/scoutapm_openapi.yaml) (default: false)")
      end

      def call(validate: false, compare_with_local: false)
        schema_data = get_client.fetch_openapi_schema
        result = base_result(schema_data)
        validate_schema_content(result, schema_data[:content]) if validate
        compare_with_local_schema(result, schema_data[:content]) if compare_with_local
        result[:content_preview] = schema_data[:content][0..500] if schema_data[:content]
        result
      end

      private

      def base_result(schema_data)
        {
          fetched: true,
          content_type: schema_data[:content_type],
          status: schema_data[:status],
          content_length: schema_data[:content].length
        }
      end

      def validate_schema_content(result, content)
        parsed = load_yaml(content)
        result[:valid_yaml] = true
        assign_openapi_metadata(result, parsed)
      rescue => error
        result[:valid_yaml] = false
        result[:validation_error] = error.message
      end

      def assign_openapi_metadata(result, parsed)
        return unless parsed.is_a?(Hash)

        result[:openapi_version] = parsed["openapi"]
        result[:info] = parsed["info"] if parsed["info"]
      end

      def load_yaml(content)
        require "yaml"
        YAML.safe_load(content)
      end

      def compare_with_local_schema(result, remote_content)
        local_schema_path = File.expand_path("tmp/scoutapm_openapi.yaml")
        unless File.exist?(local_schema_path)
          result[:local_file_exists] = false
          return
        end

        local_content = File.read(local_schema_path)
        result[:local_file_exists] = true
        result[:local_file_length] = local_content.length
        result[:content_matches] = (remote_content == local_content)
        compare_schema_structure(result, remote_content, local_content) unless result[:content_matches]
      end

      def compare_schema_structure(result, remote_content, local_content)
        remote_parsed = load_yaml(remote_content)
        local_parsed = load_yaml(local_content)
        result[:structure_matches] = (remote_parsed == local_parsed)
        assign_path_counts(result, remote_parsed, local_parsed)
      rescue => error
        result[:comparison_error] = error.message
      end

      def assign_path_counts(result, remote_parsed, local_parsed)
        return unless remote_parsed.is_a?(Hash)

        result[:remote_paths_count] = remote_parsed.dig("paths")&.keys&.length
        result[:local_paths_count] = local_parsed.dig("paths")&.keys&.length if local_parsed.is_a?(Hash)
      end
    end
  end
end
