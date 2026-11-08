require "test_helper"

class AliyunProxy::CaptchaApiDocsTest < ActionDispatch::IntegrationTest
  include AliyunProxy::Engine.routes.url_helpers

  test "publishes the current CAPTCHA contract at the correct engine boundary" do
    get openapi_spec_path

    assert_response :success
    assert_equal "3.1.2", response.parsed_body.fetch("openapi")
    assert response.parsed_body.fetch("paths").key?("/captcha/challenges/{id}")
  end
end
