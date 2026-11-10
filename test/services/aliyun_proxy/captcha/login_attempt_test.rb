require "test_helper"

class AliyunProxy::Captcha::LoginAttemptTest < ActiveSupport::TestCase
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @settings = { "aliyun_captcha_base_url" => "https://www.example.com", "aliyun_captcha_prefix" => "prefix", "aliyun_captcha_login_scene_id" => "login" }
    @original = @settings.to_h { |key, _| [key, ENV[key]] }
    ENV.update(@settings)
    @session = ActionController::TestSession.new
    @resource = { "path" => "/auth/sessions", "name" => "account" }
  end

  teardown do
    Rails.cache = @cache
    @original.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "human verification needs neither an Auth engine nor an identified user" do
    challenge = issue

    assert_equal "login_attempt", challenge.purpose
    assert_nil defined?(UserAuth::Engine)
    assert_empty @session.to_hash
  end

  test "unverified proof cannot authorize an attempt" do
    challenge = issue

    refute consume(challenge)
  end

  test "verified proof authorizes exactly one attempt" do
    challenge = issue
    verify(challenge)

    assert consume(challenge)
    refute consume(challenge)
  end

  test "proof cannot authorize another account or entry" do
    challenge = issue
    verify(challenge)

    refute AliyunProxy::Captcha::LoginAttempt.consume(id: challenge.id, session: @session, resource: @resource.merge("path" => "/other/sessions"))
    refute AliyunProxy::Captcha::LoginAttempt.consume(id: challenge.id, session: @session, resource: @resource.merge("name" => "other"))
    assert consume(challenge)
  end

  test "cookie proof cannot be moved to another browser" do
    challenge = issue
    verify(challenge)

    refute AliyunProxy::Captcha::LoginAttempt.consume(id: challenge.id, session: ActionController::TestSession.new, resource: @resource)
  end

  test "cross-origin client proof needs its original random key without API cookies" do
    key = SecureRandom.urlsafe_base64(32)
    @resource["client_origin"] = "https://app.example.com"
    challenge = issue(client_key: key)
    verify(challenge)

    refute AliyunProxy::Captcha::LoginAttempt.consume(id: challenge.id, session: @session, resource: @resource, client_key: SecureRandom.urlsafe_base64(32))
    assert AliyunProxy::Captcha::LoginAttempt.consume(id: challenge.id, session: ActionController::TestSession.new, resource: @resource, client_key: key)
  end

  private

    def issue(**options)
      AliyunProxy::Captcha::LoginAttempt.issue(session: @session, resource: @resource, return_url: "https://www.example.com/complete", **options)
    end

    def consume(challenge)
      AliyunProxy::Captcha::LoginAttempt.consume(id: challenge.id, session: @session, resource: @resource)
    end

    def verify(challenge)
      AliyunProxy::Captcha::Client.any_instance.stubs(:verify).returns("VerifyResult" => true, "VerifyCode" => "T001", "CertifyId" => challenge.attributes.fetch("certify_id"))
      challenge.verify(parameter: "provider-proof")
    end
end
