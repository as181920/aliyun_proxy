require "test_helper"

class AliyunProxy::Captcha::ClientTest < ActiveSupport::TestCase
  setup do
    @keys = %w[aliyun_captcha_access_key_id aliyun_captcha_access_key_secret aliyun_captcha_ekey]
    @original = @keys.to_h { |k| [k, ENV[k]] }
    ENV["aliyun_captcha_access_key_id"] = "test-key"
    ENV["aliyun_captcha_access_key_secret"] = "test-secret"
    ENV["aliyun_captcha_ekey"] = Base64.strict_encode64("k" * 32)
    @client = AliyunProxy::Captcha::Client.new
  end

  teardown do
    @original.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  test "sends opaque ticket unchanged with fixed server scene and ACS3 authentication" do
    request = stub_request(:post, AliyunProxy::Captcha::Client::ENDPOINT + "/")
      .with(body: { "CaptchaVerifyParam" => "opaque+/=ticket", "SceneId" => "scene" },
        headers: { "X-Acs-Action" => "VerifyIntelligentCaptcha", "X-Acs-Version" => "2023-03-05" })
      .with { |r| r.headers["Authorization"].start_with?("ACS3-HMAC-SHA256 Credential=test-key,") }
      .to_return(status: 200, body: { Success: true, Result: { VerifyResult: true, VerifyCode: "T001", CertifyId: "certify" } }.to_json)

    result = @client.verify(parameter: "opaque+/=ticket", scene_id: "scene")

    assert_equal "T001", result["VerifyCode"]
    assert_requested request
  end

  test "verification denial remains a denial" do
    stub_request(:post, /captcha.cn-shanghai/).to_return(status: 200, body: { Success: true, Result: { VerifyResult: false, VerifyCode: "F001" } }.to_json)

    refute @client.verify(parameter: "opaque", scene_id: "scene")["VerifyResult"]
  end

  test "network failure does not become verification success" do
    stub_request(:post, /captcha.cn-shanghai/).to_timeout

    assert_raises(AliyunProxy::Captcha::Client::Unavailable) { @client.verify(parameter: "opaque", scene_id: "scene") }
  end

  test "HTTP failure does not expose upstream response" do
    stub_request(:post, /captcha.cn-shanghai/).to_return(status: 403, body: { Message: "private upstream detail" }.to_json)

    error = assert_raises(AliyunProxy::Captcha::Client::Unavailable) { @client.verify(parameter: "opaque", scene_id: "scene") }

    refute_includes error.message, "private"
  end

  ["null", '{"Success":true,"Result":null}'].each do |body|
    test "malformed provider response #{body} remains unavailable" do
      stub_request(:post, /captcha.cn-shanghai/).to_return(status: 200, body:)

      assert_raises(AliyunProxy::Captcha::Client::Unavailable) { @client.verify(parameter: "opaque", scene_id: "scene") }
    end
  end

  test "missing key is a configuration error" do
    ENV.delete("aliyun_captcha_access_key_secret")

    assert_raises(AliyunProxy::Captcha::Client::ConfigurationError) { @client.verify(parameter: "opaque", scene_id: "scene") }
  end

  test "encrypted scene uses fresh IV and decrypts to official wire format" do
    first = @client.encrypted_scene_id(scene_id: "scene", lifetime: 300)
    bytes = Base64.strict_decode64(first)
    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.decrypt
    cipher.key = "k" * 32
    cipher.iv = bytes[0, 16]
    plaintext = cipher.update(bytes[16..]) + cipher.final

    scene, timestamp, lifetime = plaintext.split("&")

    assert_equal "scene", scene
    assert_in_delta Time.current.to_i - 5, timestamp.to_i, 1
    assert_equal "300", lifetime
  end

  test "encrypted scenes use a fresh IV for every generation" do
    first = @client.encrypted_scene_id(scene_id: "scene")
    second = @client.encrypted_scene_id(scene_id: "scene")

    refute_equal first, second
  end

  test "invalid encryption key is rejected" do
    ENV["aliyun_captcha_ekey"] = "invalid"

    assert_raises(AliyunProxy::Captcha::Client::ConfigurationError) { @client.encrypted_scene_id(scene_id: "scene") }
  end
end
