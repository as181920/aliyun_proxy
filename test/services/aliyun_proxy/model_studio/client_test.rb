require "test_helper"

module AliyunProxy
  module ModelStudio
    class ClientTest < ActiveSupport::TestCase
      ENVIRONMENT_KEYS = %w[
        aliyun_model_studio_api_base_url
        aliyun_model_studio_api_key
        aliyun_model_studio_workspace_id
        DASHSCOPE_API_KEY
      ].freeze

      setup do
        @original_environment = ENVIRONMENT_KEYS.to_h { |key| [key, ENV[key]] }
        ENVIRONMENT_KEYS.each { |key| ENV.delete(key) }
        ENV["aliyun_model_studio_api_key"] = "test-api-key"
        ENV["aliyun_model_studio_workspace_id"] = "workspace-123"
      end

      teardown do
        @original_environment.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      end

      test "posts JSON to the workspace endpoint with bearer authentication" do
        endpoint = "https://workspace-123.cn-beijing.maas.aliyuncs.com/example"
        request = stub_request(:post, endpoint).with(
          headers: { "Authorization" => "Bearer test-api-key", "Content-Type" => "application/json" },
          body: { input: "value" }
        ).to_return(status: 200, body: { output: "ok" }.to_json)

        result = Client.new.post("/example", payload: { input: "value" })

        assert_equal({ "output" => "ok" }, result)
        assert_requested request
      end

      test "uses an explicitly configured API base URL" do
        ENV["aliyun_model_studio_api_base_url"] = "https://model-studio.example.com"
        request = stub_request(:post, "https://model-studio.example.com/example").to_return(status: 200, body: {}.to_json)

        Client.new.post("/example", payload: {})

        assert_requested request
      end

      ["model-studio.example.com", "https://model-studio.example.com/", "  model-studio.example.com/  "].each do |base_url|
        test "normalizes configured API origin #{base_url.inspect}" do
          ENV["aliyun_model_studio_api_base_url"] = base_url
          ENV.delete("aliyun_model_studio_workspace_id")
          request = stub_request(:post, "https://model-studio.example.com/example").to_return(status: 200, body: {}.to_json)

          Client.new.post("/example", payload: {})

          assert_requested request
        end
      end

      [
        "http://model-studio.example.com", "https://model-studio.example.com/api/v1",
        "https://user:secret@model-studio.example.com",
        "https://model-studio.example.com?key=value", "https://model-studio.example.com#fragment",
        "https://", "not a domain"
      ].each do |base_url|
        test "rejects invalid API origin #{base_url.inspect}" do
          ENV["aliyun_model_studio_api_base_url"] = base_url

          assert_raises(ConfigurationError) { Client.new.post("/example", payload: {}) }
        end
      end

      test "raises a configuration error without an API key" do
        ENV.delete("aliyun_model_studio_api_key")
        ENV.delete("DASHSCOPE_API_KEY")

        assert_raises(ConfigurationError) { Client.new.post("/example", payload: {}) }
      end

      test "normalizes a failed HTTP response" do
        stub_request(:post, %r{workspace-123.*example}).to_return(
          status: 429,
          body: { message: "rate limited", request_id: "request-1" }.to_json
        )

        error = assert_raises(RequestError) { Client.new.post("/example", payload: {}) }

        assert_equal 429, error.status
        assert_equal "request-1", error.request_id
      end

      test "rejects invalid successful JSON" do
        stub_request(:post, %r{workspace-123.*example}).to_return(status: 200, body: "not-json")

        assert_raises(InvalidResponseError) { Client.new.post("/example", payload: {}) }
      end
    end
  end
end
