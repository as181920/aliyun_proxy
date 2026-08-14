module AliyunProxy
  module ModelStudio
    module Ocr
      class KeyInformationExtractionService
        ENDPOINT = "/api/v1/services/aigc/multimodal-generation/generation"
        DEFAULT_MODEL = "qwen3.5-ocr"
        MIN_PIXELS = 3_072
        MAX_PIXELS = 8_388_608

        def self.call(image:, result_schema:)
          new(image:, result_schema:).perform
        end

        def initialize(image:, result_schema:)
          @image = image
          @result_schema = result_schema
        end

        def perform
          validate_input
          response = Client.new.post(ENDPOINT, payload: request_payload)
          validate_provider_response(response)
          extract_result(response)
        end

        private

          attr_reader :image, :result_schema

          def validate_input
            raise ArgumentError, "image must be a URL or Base64 Data URL" if image.blank?
            raise ArgumentError, "result_schema must be a non-empty Hash" unless result_schema.is_a?(Hash) && result_schema.any?
          end

          def request_payload
            {
              model: configured_model,
              input: { messages: [{ role: "user", content: [image_content] }] },
              parameters: { ocr_options: ocr_options }
            }
          end

          def image_content
            { image:, min_pixels: MIN_PIXELS, max_pixels: MAX_PIXELS, enable_rotate: true }
          end

          def ocr_options
            { task: "key_information_extraction", task_config: { result_schema: } }
          end

          def configured_model
            ENV["aliyun_model_studio_ocr_model"].to_s.strip.presence || DEFAULT_MODEL
          end

          def validate_provider_response(response)
            status = response["status_code"].presence
            return if response["code"].blank? && (status.blank? || status.to_i == 200)

            raise RequestError.new(response["message"].presence || "Alibaba Cloud OCR request failed",
              status:, request_id: response["request_id"])
          end

          def extract_result(response)
            result = response.dig("output", "choices", 0, "message", "content", 0, "ocr_result", "kv_result")
            return result if result.is_a?(Hash)

            raise InvalidResponseError, "Alibaba Cloud OCR response does not contain a key information result"
          end
      end
    end
  end
end
