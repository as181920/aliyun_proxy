require "test_helper"

class AliyunProxy::Captcha::ChallengeTest < ActiveSupport::TestCase
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @keys = %w[aliyun_captcha_base_url aliyun_captcha_return_origins aliyun_captcha_prefix aliyun_captcha_reward_draw_scene_id]
    @env = @keys.to_h { |k| [k, ENV[k]] }
    ENV.update("aliyun_captcha_base_url" => "https://www.example.com", "aliyun_captcha_return_origins" => "https://activity.example.com",
      "aliyun_captcha_prefix" => "prefix", "aliyun_captcha_reward_draw_scene_id" => "scene")
    @identity = "gid://test/User/10"
    @challenge = AliyunProxy::Captcha::Challenge.issue(scene: "reward_draw", identity: @identity, purpose: "reward_draw", resource: "campaign:voucher", return_url: "https://activity.example.com/ptfs2026/#/lottery?stage=preliminary")
  end

  teardown do
    Rails.cache = @cache
    @env.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  test "verification is bound to provider certify id" do
    provider_result(certify_id: "different")

    assert_raises(AliyunProxy::Captcha::Challenge::VerificationFailed) { @challenge.verify!(parameter: "opaque") }
    refute_predicate @challenge, :verified?
  end

  %w[T002 T005].each do |code|
    test "automatic fallback #{code} does not authorize a reward" do
      provider_result(code:)

      assert_raises(AliyunProxy::Captcha::Challenge::VerificationFailed) { @challenge.verify!(parameter: "opaque") }
    end
  end

  test "verified authorization can be consumed only once" do
    verify

    assert @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
    refute @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "concurrent consumers cannot both authorize" do
    verify
    results = 2.times.map do
      Thread.new { @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher") }
    end.map(&:value)

    assert_equal({ true => 1, false => 1 }, results.tally)
  end

  test "user cannot transfer a passed challenge to another user" do
    verify

    refute @challenge.consume!(identity: "gid://test/User/11", purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "cannot transfer passed verification to another voucher or purpose" do
    verify

    refute @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:another-voucher")
    refute @challenge.consume!(identity: @identity, purpose: "login", resource: "campaign:voucher")
  end

  test "unverified and expired challenges cannot authorize" do
    refute @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
    verify
    travel 11.minutes do
      assert_raises(AliyunProxy::Captcha::Challenge::Expired) { AliyunProxy::Captcha::Challenge.find(@challenge.id) }
      refute @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
    end
  end

  test "cache write failure cannot create usable challenge" do
    Rails.cache.stubs(:write).returns(false)

    assert_raises(AliyunProxy::Captcha::Challenge::StorageUnavailable) do
      AliyunProxy::Captcha::Challenge.issue(scene: "reward_draw", identity: @identity, purpose: "reward_draw", resource: "campaign:voucher", return_url: "https://activity.example.com/")
    end
  end

  ["https://evil.example/", "https://activity.example.com.evil.example/", "https://user:secret@activity.example.com/", "//activity.example.com/", "javascript:alert(1)"].each do |url|
    test "rejects untrusted return URL #{url}" do
      assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url(url) }
    end
  end

  test "return URL retains activity path and hash route" do
    url = URI(@challenge.return_url(captcha_challenge: @challenge.id))

    assert_equal "/ptfs2026/", url.path
    assert_equal "/lottery?stage=preliminary", url.fragment
    assert_equal @challenge.id, URI.decode_www_form(url.query).to_h["captcha_challenge"]
  end

  test "same numeric id from another identity namespace cannot consume authorization" do
    verify

    refute @challenge.consume!(identity: "gid://test/TenantAuth::User/10", purpose: "reward_draw", resource: "campaign:voucher")
    assert @challenge.consume!(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "merchant identity and a distinct login purpose use the same challenge primitive" do
    ENV["aliyun_captcha_login_scene_id"] = "merchant-scene"
    challenge = AliyunProxy::Captcha::Challenge.issue(scene: "login", identity: "gid://test/TenantAuth::User/10", purpose: "tenant_login", resource: "tenant-session", return_url: "https://activity.example.com/")
    provider_result(certify_id: challenge.attributes["certify_id"])
    challenge.verify!(parameter: "opaque")

    assert challenge.consume!(identity: "gid://test/TenantAuth::User/10", purpose: "tenant_login", resource: "tenant-session")
    refute challenge.consume!(identity: "gid://test/TenantAuth::User/10", purpose: "tenant_login", resource: "tenant-session")
  ensure
    ENV.delete("aliyun_captcha_login_scene_id")
  end

  private

    def provider_result(code: "T001", certify_id: @challenge.attributes["certify_id"])
      AliyunProxy::Captcha::Client.any_instance.stubs(:verify).returns("VerifyResult" => true, "VerifyCode" => code, "CertifyId" => certify_id)
    end

    def verify
      provider_result
      @challenge.verify!(parameter: "opaque")
    end
end
