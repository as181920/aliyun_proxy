require "test_helper"

module AliyunProxy
  module ModelStudio
    module Ocr
      class KeyInformationExtractionServiceTest < ActiveSupport::TestCase
        test "returns the structured key information result" do
          client = mock
          client.expects(:post).with(KeyInformationExtractionService::ENDPOINT, payload: expected_payload).returns(success_response)
          Client.stubs(:new).returns(client)

          result = KeyInformationExtractionService.call(
            image: "data:image/jpeg;base64,image-data",
            result_schema: { "name" => "Person name" }
          )

          assert_equal({ "name" => "Ada" }, result)
        end

        test "normalizes a provider business error" do
          Client.stubs(:new).returns(stub(post: {
            "status_code" => 400,
            "code" => "InvalidParameter",
            "message" => "invalid image",
            "request_id" => "request-2"
          }))

          error = assert_raises(RequestError) do
            KeyInformationExtractionService.call(image: "https://example.com/card.jpg", result_schema: { "name" => "Name" })
          end

          assert_equal "request-2", error.request_id
        end

        test "rejects a non-success provider status even without an error code" do
          Client.stubs(:new).returns(stub(post: { "status_code" => 500, "message" => "failed" }))

          error = assert_raises(RequestError) do
            KeyInformationExtractionService.call(image: "https://example.com/card.jpg", result_schema: { "name" => "Name" })
          end

          assert_equal 500, error.status
        end

        test "rejects a response without structured OCR output" do
          Client.stubs(:new).returns(stub(post: { "output" => { "choices" => [] } }))

          assert_raises(InvalidResponseError) do
            KeyInformationExtractionService.call(image: "https://example.com/card.jpg", result_schema: { "name" => "Name" })
          end
        end

        test "requires a non-empty result schema" do
          assert_raises(ArgumentError) do
            KeyInformationExtractionService.call(image: "https://example.com/card.jpg", result_schema: {})
          end
        end

        private

          def expected_payload
            {
              model: "qwen3.5-ocr",
              input: {
                messages: [{ role: "user", content: [{
                  image: "data:image/jpeg;base64,image-data", min_pixels: 3_072, max_pixels: 8_388_608, enable_rotate: true
                }] }]
              },
              parameters: {
                ocr_options: {
                  task: "key_information_extraction",
                  task_config: { result_schema: { "name" => "Person name" } }
                }
              }
            }
          end

          def success_response
            {
              "status_code" => 200,
              "code" => "",
              "output" => {
                "choices" => [{ "message" => { "content" => [{ "ocr_result" => { "kv_result" => { "name" => "Ada" } } }] } }]
              }
            }
          end
      end
    end
  end
end
