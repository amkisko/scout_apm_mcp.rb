module ScoutApmMcp
  module Helpers
    module Identifiers
      def decode_endpoint_id(endpoint_id)
        decoded = Base64.urlsafe_decode64(endpoint_id)
        if decoded.force_encoding(Encoding::UTF_8).valid_encoding?
          decoded.force_encoding(Encoding::UTF_8)
        else
          decoded = Base64.decode64(endpoint_id)
          if decoded.force_encoding(Encoding::UTF_8).valid_encoding?
            decoded.force_encoding(Encoding::UTF_8)
          else
            endpoint_id.dup.force_encoding(Encoding::UTF_8)
          end
        end
      rescue
        endpoint_id.dup.force_encoding(Encoding::UTF_8)
      end

      def get_endpoint_id(endpoint)
        link = endpoint["link"] || endpoint[:link] || ""
        return "" if link.empty?

        link.split("/").last || ""
      end

      def get_job_id(job)
        job["job_id"] || job[:job_id] || ""
      end
    end
  end
end
