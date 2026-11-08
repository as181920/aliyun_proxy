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
end
