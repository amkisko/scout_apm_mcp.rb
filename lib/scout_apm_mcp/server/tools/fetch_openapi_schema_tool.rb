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

        result = {
          fetched: true,
          content_type: schema_data[:content_type],
          status: schema_data[:status],
          content_length: schema_data[:content].length
        }

        if validate
          begin
            require "yaml"
            parsed = YAML.safe_load(schema_data[:content])
            result[:valid_yaml] = true
            result[:openapi_version] = parsed["openapi"] if parsed.is_a?(Hash)
            result[:info] = parsed["info"] if parsed.is_a?(Hash) && parsed["info"]
          rescue => e
            result[:valid_yaml] = false
            result[:validation_error] = e.message
          end
        end

        if compare_with_local
          local_schema_path = File.expand_path("tmp/scoutapm_openapi.yaml")
          if File.exist?(local_schema_path)
            local_content = File.read(local_schema_path)
            result[:local_file_exists] = true
            result[:local_file_length] = local_content.length
            result[:content_matches] = (schema_data[:content] == local_content)

            unless result[:content_matches]
              begin
                require "yaml"
                remote_parsed = YAML.safe_load(schema_data[:content])
                local_parsed = YAML.safe_load(local_content)
                result[:structure_matches] = (remote_parsed == local_parsed)
                result[:remote_paths_count] = remote_parsed.dig("paths")&.keys&.length if remote_parsed.is_a?(Hash)
                result[:local_paths_count] = local_parsed.dig("paths")&.keys&.length if local_parsed.is_a?(Hash)
              rescue => e
                result[:comparison_error] = e.message
              end
            end
          else
            result[:local_file_exists] = false
          end
        end

        # Include a preview of the content (first 500 chars) for inspection
        result[:content_preview] = schema_data[:content][0..500] if schema_data[:content]

        result
      end
    end
  end
end
