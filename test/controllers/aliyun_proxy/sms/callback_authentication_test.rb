require "test_helper"

class AliyunProxy::Sms::CallbackAuthenticationTest < ActionDispatch::IntegrationTest
  include AliyunProxy::Engine.routes.url_helpers

  setup do
    https!
    @previous_token = ENV["aliyun_sms_callback_token"]
    @token = SecureRandom.urlsafe_base64(32)
    ENV["aliyun_sms_callback_token"] = @token
    @previous_protection = AliyunProxy::ApplicationController.allow_forgery_protection
    AliyunProxy::ApplicationController.allow_forgery_protection = true
    @sign = AliyunProxy::Sms::Sign.create!(name: "Callback sign", state: :approved)
    @report = [{ sign_name: @sign.name, sign_status: "rejected", reason: "Review reason" }]
  end

  teardown do
    @previous_token ? ENV["aliyun_sms_callback_token"] = @previous_token : ENV.delete("aliyun_sms_callback_token")
    AliyunProxy::ApplicationController.allow_forgery_protection = @previous_protection
  end

  test "authenticated cloud JSON callbacks work without browser cookies or a CSRF token" do
    post sms_callback_sign_reports_path(callback_token: @token), params: @report, as: :json

    assert_response :success
    assert_equal({ "code" => 0, "msg" => "成功" }, response.parsed_body)
    assert_predicate @sign.reload, :rejected?
  end

  test "a missing callback credential cannot query or update signatures" do
    AliyunProxy::Sms::Sign.expects(:find_by).never
    post sms_callback_sign_reports_path, params: @report, as: :json

    assert_response :unauthorized
    assert_predicate @sign.reload, :approved?
  end

  test "an invalid callback credential cannot query or update signatures" do
    AliyunProxy::Sms::Sign.expects(:find_by).never
    post sms_callback_sign_reports_path(callback_token: "invalid"), params: @report, as: :json

    assert_response :unauthorized
  end

  test "a body field cannot replace the separately configured callback credential" do
    AliyunProxy::Sms::Sign.expects(:find_by).never
    post sms_callback_sign_reports_path, params: { callback_token: @token, _json: @report }, as: :json

    assert_response :unauthorized
  end

  test "a cookie or Basic header cannot replace callback authentication" do
    post sms_callback_sign_reports_path, params: @report, headers: { "Authorization" => "Basic placeholder" }, as: :json

    assert_response :unauthorized
  end

  test "callbacks retain their normal processing when the optional credential is unconfigured" do
    ENV.delete("aliyun_sms_callback_token")
    post sms_callback_sign_reports_path, params: @report, as: :json

    assert_response :success
    assert_predicate @sign.reload, :rejected?
  end

  ["", "   "].each do |value|
    test "a #{value.empty? ? 'blank' : 'whitespace'} optional credential skips callback authentication" do
      ENV["aliyun_sms_callback_token"] = value
      post sms_callback_sign_reports_path(callback_token: "ignored"), params: @report, as: :json

      assert_response :success
      assert_predicate @sign.reload, :rejected?
    end
  end

  test "short callback credentials are rejected as misconfiguration" do
    ENV["aliyun_sms_callback_token"] = "short"
    post sms_callback_sign_reports_path(callback_token: "short"), params: @report, as: :json

    assert_response :service_unavailable
  end

  test "GET connectivity cannot bypass a short configured credential" do
    ENV["aliyun_sms_callback_token"] = "short"
    get sms_callback_sign_reports_path(callback_token: "short")

    assert_response :service_unavailable
  end

  test "GET connectivity rejects an incorrect credential when authentication is enabled" do
    get sms_callback_sign_reports_path(callback_token: "incorrect")

    assert_response :unauthorized
  end

  %i[up_messages template_reports message_reports].each do |endpoint|
    test "#{endpoint} authenticates cloud JSON before acknowledging without CSRF" do
      post public_send("sms_callback_#{endpoint}_path", callback_token: @token), params: [], as: :json

      assert_response :success
      assert_equal 0, response.parsed_body.fetch("code")
    end

    test "#{endpoint} rejects unauthenticated cloud JSON" do
      post public_send("sms_callback_#{endpoint}_path"), params: [], as: :json

      assert_response :unauthorized
    end

    test "#{endpoint} accepts cloud JSON when optional authentication is disabled" do
      ENV.delete("aliyun_sms_callback_token")
      post public_send("sms_callback_#{endpoint}_path"), params: [], as: :json

      assert_response :success
      assert_equal 0, response.parsed_body.fetch("code")
    end
  end

  %i[sign_reports up_messages template_reports message_reports].each do |endpoint|
    test "#{endpoint} responds to authenticated GET connectivity checks without querying signatures" do
      AliyunProxy::Sms::Sign.expects(:find_by).never
      get public_send("sms_callback_#{endpoint}_path", callback_token: @token), params: { sign_status: "rejected" }

      assert_response :success
      assert_equal({ "code" => 0, "msg" => "成功" }, response.parsed_body)
      assert_predicate @sign.reload, :approved?
    end

    test "#{endpoint} rejects GET checks without a credential when authentication is enabled" do
      get public_send("sms_callback_#{endpoint}_path")

      assert_response :unauthorized
    end

    test "#{endpoint} accepts GET checks when optional authentication is disabled" do
      ENV.delete("aliyun_sms_callback_token")
      get public_send("sms_callback_#{endpoint}_path")

      assert_response :success
      assert_equal 0, response.parsed_body.fetch("code")
    end
  end
end
