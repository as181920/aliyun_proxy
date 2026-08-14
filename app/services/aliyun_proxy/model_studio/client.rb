module AliyunProxy
  module ModelStudio
    class Client
      OPEN_TIMEOUT = 3
      READ_TIMEOUT = 30

      def post(path, payload:)
        response = connection.post(path) do |request|
          request.headers["Authorization"] = "Bearer #{api_key}"
          request.headers["Content-Type"] = "application/json"
          request.body = JSON.generate(payload)
        end
        parse_response(response)
      rescue Faraday::Error => e
        raise RequestError, "Alibaba Cloud Model Studio request failed: #{e.message}"
      end

      private

        def connection
          @connection ||= Faraday.new(url: api_base_url, request: { open_timeout: OPEN_TIMEOUT, timeout: READ_TIMEOUT })
        end

        def parse_response(response)
          body = JSON.parse(response.body)
          return body if response.success?

          raise_request_error(response.status, body)
        rescue JSON::ParserError
          raise InvalidResponseError, "Alibaba Cloud Model Studio returned invalid JSON" if response.success?

          raise RequestError.new("Alibaba Cloud Model Studio request failed with HTTP #{response.status}", status: response.status)
        end

        def raise_request_error(status, body)
          message = body["message"].to_s.strip.presence || "Alibaba Cloud Model Studio request failed"
          raise RequestError.new(message, status:, request_id: body["request_id"])
        end

        def api_key
          value = ENV["aliyun_model_studio_api_key"].to_s.strip.presence || ENV["DASHSCOPE_API_KEY"].to_s.strip.presence
          return value if value

          raise ConfigurationError, "Alibaba Cloud Model Studio API key is not configured"
        end

        def api_base_url
          ENV["aliyun_model_studio_api_base_url"].to_s.strip.presence || default_api_base_url
        end

        def default_api_base_url
          workspace_id = ENV["aliyun_model_studio_workspace_id"].to_s
          unless workspace_id.match?(/\A[a-zA-Z0-9-]+\z/)
            raise ConfigurationError, "Alibaba Cloud Model Studio workspace ID is not configured or invalid"
          end

          "https://#{workspace_id}.cn-beijing.maas.aliyuncs.com"
        end
    end
  end
end
