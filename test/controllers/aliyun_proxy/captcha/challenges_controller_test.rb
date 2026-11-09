require "test_helper"

class AliyunProxy::Captcha::ChallengesControllerTest < ActionController::TestCase
  setup do
    @routes = AliyunProxy::Engine.routes
    @request.host = "www.example.com"
    @request.env["HTTPS"] = "on"
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @settings = {
      "aliyun_captcha_base_url" => "https://www.example.com", "aliyun_captcha_prefix" => "prefix",
      "aliyun_captcha_login_scene_id" => "shared-login", "aliyun_captcha_encryption_enabled" => "0"
    }
    @original = @settings.to_h { |key, _| [key, ENV[key]] }
    ENV.update(@settings)
    browser_key = AliyunProxy::Captcha::BrowserBinding.key(session)
    @challenge = AliyunProxy::Captcha::Challenge.issue(identity: "opaque-identity", scene: "login", purpose: "consumer-purpose", resource: "opaque-resource", browser_key:, return_url: "https://www.example.com/consumer-callback")
  end

  teardown do
    Rails.cache = @cache
    @original.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "standalone provider renders without any Auth engine" do
    get :show, params: { id: @challenge.id }

    assert_response :success
    assert_nil defined?(UserAuth::Engine)
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
  end

  test "page preserves CSP and Turbo style lifecycle" do
    get :show, params: { id: @challenge.id }

    assert_select 'style[data-turbo-track="dynamic"]'
    assert_select 'script[type="importmap"]'
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "page renders a hidden SDK trigger and a disabled progress control" do
    get :show, params: { id: @challenge.id }

    assert_select "#captcha-trigger[hidden]"
    assert_select "#captcha-button[disabled]", text: I18n.t("aliyun_proxy.captcha.loading")
  end

  test "page rejects a different browser" do
    @request.session = ActionController::TestSession.new
    get :show, params: { id: @challenge.id }

    assert_response :forbidden
  end

  test "expired page reports expiry instead of rendering the SDK" do
    travel 11.minutes do
      get :show, params: { id: @challenge.id }
    end

    assert_response :gone
    assert_select "#captcha-button", count: 0
  end

  test "successful verification returns consumer callback without consuming the proof" do
    provider_result
    patch :update, params: { id: @challenge.id, captcha: { verify_param: "opaque-ticket" } }, as: :json

    assert_response :success
    assert_equal @challenge.return_url(captcha_challenge: @challenge.id), response.parsed_body.fetch("redirect_url")
    refute_predicate @challenge, :consumed?
  end

  test "failed provider response cannot authorize" do
    provider_result(code: "F001")
    patch :update, params: { id: @challenge.id, captcha: { verify_param: "opaque-ticket" } }, as: :json

    assert_response :unprocessable_entity
    refute_predicate @challenge, :verified?
  end

  test "unavailable vendor fails closed" do
    AliyunProxy::Captcha::Client.any_instance.stubs(:verify).raises(AliyunProxy::Captcha::Client::Unavailable)
    patch :update, params: { id: @challenge.id, captcha: { verify_param: "opaque-ticket" } }, as: :json

    assert_response :service_unavailable
    assert_equal "captcha.unavailable", response.parsed_body.dig("error", "code")
  end

  test "JSON update still requires csrf for browser-bound challenge" do
    original = @controller.class.allow_forgery_protection
    @controller.class.allow_forgery_protection = true

    assert_raises(ActionController::InvalidAuthenticityToken) do
      patch :update, params: { id: @challenge.id, captcha: { verify_param: "opaque-ticket" } }, as: :json
    end
  ensure
    @controller.class.allow_forgery_protection = original
  end

  test "locale query switches the whole page to English" do
    get :show, params: { id: @challenge.id, locale: "en" }

    assert_select "html[lang=en]"
    assert_select "h1", text: "Security verification"
    assert_includes response.body, "locale=en"
  end

  test "provider SDK follows the page locale" do
    get :show, params: { id: @challenge.id, locale: "en" }

    assert_includes response.body, '"language":"en"'
  end

  test "expired challenge 1 also renders its page and message in English" do
    get :show, params: { id: "1", locale: "en" }

    assert_response :gone
    assert_select "h1", text: "Security verification"
    assert_select "h2", text: "Verification expired. Return and start again."
  end

  test "locale query switches the page to Chinese" do
    get :show, params: { id: @challenge.id, locale: "zh-CN" }

    assert_select "html[lang=zh-CN]"
    assert_select "h1", text: "安全验证"
  end

  test "invalid locale safely falls back to application default" do
    get :show, params: { id: @challenge.id, locale: "invalid" }

    assert_response :success
    assert_select "html[lang='#{I18n.default_locale}']"
  end

  test "browser language weights select a supported locale" do
    @request.headers["Accept-Language"] = "ja;q=1,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7"
    get :show, params: { id: @challenge.id }

    assert_select "html[lang=en]"
    assert_select "h1", text: "Security verification"
  end

  test "explicit locale takes priority over browser language" do
    @request.headers["Accept-Language"] = "en-US,en;q=0.9"
    get :show, params: { id: @challenge.id, locale: "zh-CN" }

    assert_select "html[lang=zh-CN]"
  end

  test "unsupported browser language falls back to application default" do
    @request.headers["Accept-Language"] = "unsupported"
    get :show, params: { id: @challenge.id }

    assert_select "html[lang='#{I18n.default_locale}']"
  end

  test "expired page also detects browser language" do
    @request.headers["Accept-Language"] = "en-US,en;q=0.9"
    get :show, params: { id: "1" }

    assert_response :gone
    assert_select "h2", text: "Verification expired. Return and start again."
  end

  test "verification callback does not inject provider locale" do
    provider_result
    patch :update, params: { id: @challenge.id, locale: "en", captcha: { verify_param: "opaque-ticket" } }, as: :json

    refute URI.decode_www_form(URI(response.parsed_body.fetch("redirect_url")).query).to_h.key?("locale")
  end

  private

    def provider_result(code: "T001")
      AliyunProxy::Captcha::Client.any_instance.stubs(:verify).returns(
        "VerifyResult" => code == "T001", "VerifyCode" => code, "CertifyId" => @challenge.attributes.fetch("certify_id")
      )
    end
end
