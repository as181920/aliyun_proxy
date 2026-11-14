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

    assert_raises(AliyunProxy::Captcha::Challenge::VerificationFailed) { @challenge.verify(parameter: "opaque") }
    refute_predicate @challenge, :verified?
  end

  %w[T002 T005].each do |code|
    test "automatic fallback #{code} does not authorize a reward" do
      provider_result(code:)

      assert_raises(AliyunProxy::Captcha::Challenge::VerificationFailed) { @challenge.verify(parameter: "opaque") }
    end
  end

  test "verified authorization can be consumed only once" do
    verify

    assert @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
    refute @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "concurrent consumers cannot both authorize" do
    verify
    results = 2.times.map do
      Thread.new { @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher") }
    end.map(&:value)

    assert_equal({ true => 1, false => 1 }, results.tally)
  end

  test "user cannot transfer a passed challenge to another user" do
    verify

    refute @challenge.consume(identity: "gid://test/User/11", purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "cannot transfer passed verification to another voucher or purpose" do
    verify

    refute @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:another-voucher")
    refute @challenge.consume(identity: @identity, purpose: "login", resource: "campaign:voucher")
  end

  test "unverified and expired challenges cannot authorize" do
    refute @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
    verify
    travel 11.minutes do
      assert_raises(AliyunProxy::Captcha::Challenge::Expired) { AliyunProxy::Captcha::Challenge.find(@challenge.id) }
      refute @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
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

    refute @challenge.consume(identity: "gid://test/TenantAuth::User/10", purpose: "reward_draw", resource: "campaign:voucher")
    assert @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "browser binding checks the current state under the state lock" do
    stale_challenge = AliyunProxy::Captcha::Challenge.find(@challenge.id)
    verify
    @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")

    assert_raises(AliyunProxy::Captcha::Challenge::Expired) { stale_challenge.bind_browser(key: "this-browser") }
    assert_predicate @challenge, :consumed?
  end

  test "merchant identity and a distinct login purpose use the same challenge primitive" do
    ENV["aliyun_captcha_login_scene_id"] = "merchant-scene"
    challenge = AliyunProxy::Captcha::Challenge.issue(scene: "login", identity: "gid://test/TenantAuth::User/10", purpose: "tenant_login", resource: "tenant-session", return_url: "https://activity.example.com/")
    provider_result(certify_id: challenge.attributes["certify_id"])
    challenge.verify(parameter: "opaque")

    assert challenge.consume(identity: "gid://test/TenantAuth::User/10", purpose: "tenant_login", resource: "tenant-session")
    refute challenge.consume(identity: "gid://test/TenantAuth::User/10", purpose: "tenant_login", resource: "tenant-session")
  ensure
    ENV.delete("aliyun_captcha_login_scene_id")
  end

  test "revoking a verified challenge prevents later authorization" do
    verify
    @challenge.revoke

    assert_raises(AliyunProxy::Captcha::Challenge::Expired) { AliyunProxy::Captcha::Challenge.find(@challenge.id) }
    refute @challenge.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "an old challenge instance cannot resurrect revoked verification" do
    stale = AliyunProxy::Captcha::Challenge.find(@challenge.id)
    @challenge.revoke
    provider_result

    assert_raises(AliyunProxy::Captcha::Challenge::Expired) { stale.verify(parameter: "opaque") }
  end

  test "the verification outcome is request local and is not stored with the challenge" do
    verify

    assert_equal :verified, @challenge.verification_outcome
    refute AliyunProxy::Captcha::Challenge.find(@challenge.id).attributes.key?("verification_outcome")
  end

  [nil, "", "   ", 123, "x" * 16_385].each_with_index do |parameter, index|
    test "invalid parameter #{index} is identified before calling the provider" do
      AliyunProxy::Captcha::Client.expects(:new).never

      assert_raises(ArgumentError) { @challenge.verify(parameter:) }
      assert_equal :invalid, @challenge.verification_outcome
    end
  end

  test "a provider rejection is distinguishable from a local state failure" do
    provider_result(code: "F001")

    assert_raises(AliyunProxy::Captcha::Challenge::VerificationFailed) { @challenge.verify(parameter: "opaque") }
    assert_equal :failed, @challenge.verification_outcome
  end

  test "a provider outage records a technical outcome" do
    AliyunProxy::Captcha::Client.any_instance.stubs(:verify).raises(AliyunProxy::Captcha::Client::Unavailable)

    assert_raises(AliyunProxy::Captcha::Client::Unavailable) { @challenge.verify(parameter: "opaque") }
    assert_equal :error, @challenge.verification_outcome
  end

  test "a successful vendor result cannot mask failure to save verified state" do
    provider_result
    Rails.cache.stubs(:write).returns(false)

    assert_raises(AliyunProxy::Captcha::Challenge::StorageUnavailable) { @challenge.verify(parameter: "opaque") }
    assert_equal :error, @challenge.verification_outcome
  end

  test "a state conflict after a passed vendor result is not a human rejection" do
    provider_result
    @challenge.stubs(:with_state_lock).raises(AliyunProxy::Captcha::Challenge::VerificationFailed)

    assert_raises(AliyunProxy::Captcha::Challenge::VerificationFailed) { @challenge.verify(parameter: "opaque") }
    assert_equal :error, @challenge.verification_outcome
  end

  test "replaying verified state does not retain an earlier vendor outcome" do
    verify
    @challenge.verify(parameter: "opaque")

    assert_nil @challenge.verification_outcome
  end

  test "retained metadata cannot make an expired verified challenge verify again" do
    verify
    travel 11.minutes
    retained = AliyunProxy::Captcha::Challenge.find_for_observation(@challenge.id)

    assert_raises(AliyunProxy::Captcha::Challenge::Expired) { retained.verify(parameter: "opaque") }
  end

  test "retained metadata cannot consume expired verification" do
    verify
    travel 11.minutes
    retained = AliyunProxy::Captcha::Challenge.find_for_observation(@challenge.id)

    refute retained.consume(identity: @identity, purpose: "reward_draw", resource: "campaign:voucher")
  end

  test "retained metadata cannot bind an expired browser challenge" do
    travel 11.minutes
    retained = AliyunProxy::Captcha::Challenge.find_for_observation(@challenge.id)

    assert_raises(AliyunProxy::Captcha::Challenge::Expired) { retained.bind_browser(key: "browser") }
  end

  test "expired verification is not reported as currently verified" do
    verify
    travel 11.minutes

    refute_predicate @challenge, :verified?
  end

  test "reading retained metadata does not extend its original deadline" do
    travel 14.minutes
    AliyunProxy::Captcha::Challenge.find_for_observation(@challenge.id)
    travel 2.minutes

    assert_raises(AliyunProxy::Captcha::Challenge::Expired) { AliyunProxy::Captcha::Challenge.find_for_observation(@challenge.id) }
  end

  private

    def provider_result(code: "T001", certify_id: @challenge.attributes["certify_id"])
      AliyunProxy::Captcha::Client.any_instance.stubs(:verify).returns("VerifyResult" => true, "VerifyCode" => code, "CertifyId" => certify_id)
    end

    def verify
      provider_result
      @challenge.verify(parameter: "opaque")
    end
end
