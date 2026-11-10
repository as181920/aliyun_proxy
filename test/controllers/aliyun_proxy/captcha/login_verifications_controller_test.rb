require "test_helper"

class AliyunProxy::Captcha::LoginVerificationsControllerTest < ActionController::TestCase
  setup do
    @routes = AliyunProxy::Engine.routes
    @request.host = "www.example.com"
    @request.env["HTTPS"] = "on"
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @settings = { "aliyun_captcha_base_url" => "https://www.example.com", "aliyun_captcha_prefix" => "prefix", "aliyun_captcha_login_scene_id" => "login" }
    @original = @settings.to_h { |key, _| [key, ENV[key]] }
    ENV.update(@settings)
    @challenge = AliyunProxy::Captcha::LoginAttempt.issue(session:, resource: { "path" => "/login" }, return_url: "https://www.example.com/complete")
  end

  teardown do
    Rails.cache = @cache
    @original.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "expired HTML callback renders an explanation" do
    travel 11.minutes do
      get :show, params: { captcha_challenge: @challenge.id }
    end

    assert_response :gone
    assert_select '[role="alert"]', text: I18n.t("aliyun_proxy.captcha.expired")
  end

  test "expired JSON callback returns the shared error contract" do
    travel 11.minutes do
      get :show, params: { captcha_challenge: @challenge.id }, format: :json
    end

    assert_response :gone
    assert_equal "captcha.expired", response.parsed_body.dig("error", "code")
  end

  test "unverified callback renders forbidden without notifying success" do
    get :show, params: { captcha_challenge: @challenge.id }

    assert_response :forbidden
    assert_select '[role="alert"]'
    refute_includes response.body, "captcha_verified"
  end

  test "another browser receives a structured forbidden error" do
    @request.session = ActionController::TestSession.new
    get :show, params: { captcha_challenge: @challenge.id }, format: :json

    assert_response :forbidden
    assert_equal "captcha.browser_mismatch", response.parsed_body.dig("error", "code")
  end

  test "unavailable storage renders a retry explanation" do
    AliyunProxy::Captcha::Challenge.stubs(:find).raises(AliyunProxy::Captcha::Challenge::StorageUnavailable)
    get :show, params: { captcha_challenge: @challenge.id }

    assert_response :service_unavailable
    assert_select '[role="alert"]', text: I18n.t("aliyun_proxy.captcha.unavailable")
  end

  test "cancelling notifies the parent without consuming or authenticating" do
    get :show, params: { captcha_challenge: @challenge.id, captcha_status: "cancelled" }

    assert_response :success
    assert_includes response.body, "aliyun_proxy:captcha_cancelled"
    refute_predicate @challenge, :consumed?
  end
end
