require "test_helper"

class AliyunProxy::CaptchaApiDocsTest < ActionDispatch::IntegrationTest
  include AliyunProxy::Engine.routes.url_helpers

  test "publishes the current CAPTCHA contract at the correct engine boundary" do
    get openapi_spec_path

    assert_response :success
    assert_equal "3.1.2", response.parsed_body.fetch("openapi")
    assert response.parsed_body.fetch("paths").key?("/captcha/challenges/{id}")
  end

  test "publishes PNVS user authentication separately from cloud callbacks" do
    get role_openapi_spec_path(role: :user)

    assert_response :success
    assert response.parsed_body.fetch("paths").key?("/pnvs/auth_tokens")
    refute response.parsed_body.fetch("paths").key?("/sms/callback/sign_reports")
  end

  test "publishes the JSON callback authentication boundary" do
    get role_openapi_spec_path(role: :callbacks)

    assert_response :success
    assert_equal 4, response.parsed_body.fetch("paths").size
    assert_equal "query", response.parsed_body.dig("components", "securitySchemes", "callbackCredential", "in")
  end

  test "documents optional callback authentication for both GET and POST" do
    get role_openapi_spec_path(role: :callbacks)
    response.parsed_body.fetch("paths").each_value do |path|
      %w[get post].each do |method|
        assert_equal [{}, { "callbackCredential" => [] }], path.fetch(method).fetch("security")
      end
    end
  end

  test "documents GET connectivity without a business request body" do
    get role_openapi_spec_path(role: :callbacks)
    response.parsed_body.fetch("paths").each_value do |path|
      get_operation = path.fetch("get")

      refute get_operation.key?("requestBody")
      assert_equal "#/components/schemas/CallbackAcknowledgement",
                   get_operation.dig("responses", "200", "content", "application/json", "schema", "$ref")
    end
  end

  test "unknown specifications cannot select an arbitrary file" do
    get role_openapi_spec_path(role: :unrecognized)

    assert_response :not_found
  end
end
