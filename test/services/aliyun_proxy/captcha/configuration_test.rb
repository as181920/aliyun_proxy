require "test_helper"

class AliyunProxy::Captcha::ConfigurationTest < ActiveSupport::TestCase
  [true, "true", "TRUE", 1, "1", "on", "ON"].each do |value|
    test "login enabled accepts #{value.inspect}" do
      ENV.stubs(:[]).with("aliyun_captcha_login_enabled").returns(value)

      assert AliyunProxy::Captcha::Configuration.enabled?("login")
    end
  end

  [false, "false", "FALSE", 0, "0", "off", "OFF", "", nil].each do |value|
    test "login disabled accepts #{value.inspect}" do
      ENV.stubs(:[]).with("aliyun_captcha_login_enabled").returns(value)

      refute AliyunProxy::Captcha::Configuration.enabled?("login")
    end
  end

  test "encryption uses the same boolean conversion" do
    ENV.stubs(:[]).with("aliyun_captcha_reward_draw_scene_id").returns("scene")
    ENV.stubs(:[]).with("aliyun_captcha_encryption_enabled").returns("1")
    AliyunProxy::Captcha::Client.any_instance.expects(:encrypted_scene_id).with(scene_id: "scene").returns("encrypted-scene")

    assert_equal "encrypted-scene", AliyunProxy::Captcha::Configuration.client_options(scene: "reward_draw", certify_id: "certify")[:EncryptedSceneId]
  end

  test "disabled encryption does not require a key" do
    ENV.stubs(:[]).with("aliyun_captcha_reward_draw_scene_id").returns("scene")
    ENV.stubs(:[]).with("aliyun_captcha_encryption_enabled").returns("false")
    AliyunProxy::Captcha::Client.any_instance.expects(:encrypted_scene_id).never

    refute AliyunProxy::Captcha::Configuration.client_options(scene: "reward_draw", certify_id: "certify").key?(:EncryptedSceneId)
  end

  %w[https://code-li.com https://shfs-c.code-li.com https://activity.customer.code-li.com https://SHFS-C.CODE-LI.COM].each do |url|
    test "configured root and wildcard allow #{url}" do
      allow_origins("https://code-li.com,https://*.code-li.com")

      assert_equal url, AliyunProxy::Captcha::Configuration.valid_return_url(url)
    end
  end

  test "explicit default HTTPS port matches the configured wildcard" do
    allow_origins("https://*.code-li.com")

    assert_equal "https://shfs-c.code-li.com", AliyunProxy::Captcha::Configuration.valid_return_url("https://shfs-c.code-li.com:443")
  end

  %w[https://evilcode-li.com https://code-li.com.evil.example https://shfs.code-li.com.evil.example https://code-li.com@evil.example https://evil.example/?host=shfs.code-li.com https://evil.example/#https://shfs.code-li.com https://shfs-c.code-li.com:8443 http://shfs-c.code-li.com https://*.code-li.com https://.code-li.com https://a..code-li.com].each do |url|
    test "wildcard rejects #{url}" do
      allow_origins("https://*.code-li.com")

      assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url(url) }
    end
  end

  test "wildcard does not implicitly include its root domain" do
    allow_origins("https://*.code-li.com")

    assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url("https://code-li.com") }
  end

  test "wildcard preserves the original return path query and fragment" do
    allow_origins("https://*.code-li.com")
    url = "https://shfs-c.code-li.com/ptfs2026/?source=poster#/lottery-dial"

    assert_equal url, AliyunProxy::Captcha::Configuration.valid_return_url(url)
  end

  test "explicit external origin remains supported" do
    allow_origins("https://*.code-li.com, https://customer.example:8443")

    assert_equal "https://customer.example:8443/return", AliyunProxy::Captcha::Configuration.valid_return_url("https://customer.example:8443/return")
  end

  test "explicit external origin does not trust its subdomains" do
    allow_origins("https://customer.example")

    assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url("https://child.customer.example") }
  end

  test "wildcard can explicitly specify a nondefault port" do
    allow_origins("https://*.code-li.com:8443")

    assert_equal "https://shfs-c.code-li.com:8443", AliyunProxy::Captcha::Configuration.valid_return_url("https://shfs-c.code-li.com:8443")
  end

  test "wildcard with a nondefault port does not permit the default port" do
    allow_origins("https://*.code-li.com:8443")

    assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url("https://shfs-c.code-li.com") }
  end

  test "base origin is automatically allowed without configured return origins" do
    allow_origins("")

    assert_equal "https://www.example.com/return", AliyunProxy::Captcha::Configuration.valid_return_url("https://www.example.com/return")
  end

  test "development localhost requires its configured port" do
    allow_origins("http://localhost:3000")

    assert_equal "http://localhost:3000/return", AliyunProxy::Captcha::Configuration.valid_return_url("http://localhost:3000/return")
  end

  test "development localhost on another port is rejected" do
    allow_origins("http://localhost:3000")

    assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url("http://localhost:3001/return") }
  end

  test "production rejects even explicitly configured localhost HTTP" do
    allow_origins("http://localhost:3000")
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))

    assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url("http://localhost:3000/return") }
  end

  %w[https://*.code-li.com/path https://*.code-li.com?query=yes https://*.code-li.com#fragment https://user@*.code-li.com https://shfs-*.code-li.com https://* not-an-origin https://[].code-li.com].each do |pattern|
    test "invalid origin pattern #{pattern} cannot authorize a return" do
      allow_origins(pattern)

      assert_raises(ArgumentError) { AliyunProxy::Captcha::Configuration.valid_return_url("https://shfs-c.code-li.com") }
    end
  end

  test "base URL retains its application frontend fallback" do
    ENV.stubs(:[]).with("aliyun_captcha_base_url").returns(nil)
    ENV.stubs(:[]).with("app_frontend_base_url").returns("https://www.code-li.com")

    assert_equal "https://www.code-li.com", AliyunProxy::Captcha::Configuration.base_url
  end

  private

    def allow_origins(value)
      AliyunProxy::Captcha::Configuration.stubs(:base_url).returns("https://www.example.com")
      ENV.stubs(:fetch).with("aliyun_captcha_return_origins", "").returns(value)
    end
end
