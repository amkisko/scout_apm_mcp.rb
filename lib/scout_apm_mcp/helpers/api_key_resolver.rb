module ScoutApmMcp
  module Helpers
    module ApiKeyResolver
      def read_op_secret(reference)
        stdout, _stderr, status = Open3.capture3("op", "read", reference)
        return stdout.strip if status.success? && !stdout.strip.empty?

        nil
      rescue
        nil
      end

      def get_api_key(api_key: nil, op_vault: nil, op_item: nil, op_field: "API_KEY")
        direct_key = api_key if api_key && !api_key.empty?
        return direct_key if direct_key

        environment_key = ENV["API_KEY"] || ENV["SCOUT_APM_API_KEY"]
        return environment_key if environment_key && !environment_key.empty?

        resolved_key = api_key_from_op_env_entry(op_field) || api_key_from_opdotenv(op_vault, op_item, op_field)
        return resolved_key if resolved_key && !resolved_key.empty?

        raise_missing_api_key
      end

      private

      def api_key_from_op_env_entry(op_field)
        op_env_entry_path = ENV["OP_ENV_ENTRY_PATH"]
        return nil if op_env_entry_path.nil? || op_env_entry_path.empty?
        return nil unless op_env_entry_path =~ %r{op://([^/]+)/(.+)}

        vault = Regexp.last_match(1)
        item = Regexp.last_match(2)
        read_op_secret("op://#{vault}/#{item}/#{op_field}")
      rescue
        nil
      end

      def api_key_from_opdotenv(op_vault, op_item, op_field)
        return nil unless op_vault && op_item

        api_key = api_key_from_opdotenv_loader(op_vault, op_item)
        return api_key if api_key && !api_key.empty?

        read_op_secret("op://#{op_vault}/#{op_item}/#{op_field}")
      rescue
        nil
      end

      def api_key_from_opdotenv_loader(op_vault, op_item)
        require "opdotenv"
        Opdotenv::Loader.load("op://#{op_vault}/#{op_item}")
        api_key = ENV["API_KEY"] || ENV["SCOUT_APM_API_KEY"]
        api_key if api_key && !api_key.empty?
      rescue LoadError
        nil
      rescue
        nil
      end

      def raise_missing_api_key
        raise "API_KEY not found. " \
              "Set API_KEY or SCOUT_APM_API_KEY environment variable, " \
              "or provide OP_ENV_ENTRY_PATH, or op_vault and op_item parameters for 1Password integration"
      end
    end
  end
end
