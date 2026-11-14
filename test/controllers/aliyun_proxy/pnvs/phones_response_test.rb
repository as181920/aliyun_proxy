require "test_helper"

class AliyunProxy::Pnvs::PhonesResponseTest < ActionController::TestCase
  tests AliyunProxy::Pnvs::PhonesController

  setup do
    @routes = AliyunProxy::Engine.routes
    @user = Struct.new(:id).new(123)
    @controller.stubs(:current_user).returns(@user)
    # Phone persistence belongs to the existing binding callback; isolate rendering here.
    @controller.stubs(:bind_user_phone)
  end

  test "the JSON response retains the authenticated user's phone payload" do
    AliyunProxy::Pnvs::PhoneService.any_instance.stubs(:get_number).with(sp_token: "proof").returns(
      { "Data" => { "Mobile" => "13800000000" } }
    )
    post :create, params: { phone: { sp_token: "proof" } }, format: :json

    assert_response :success
    assert_equal({ "user_id" => @user.id, "number" => "13800000000" }, response.parsed_body.fetch("phone"))
  end

  test "a missing provider phone returns the standard error envelope" do
    AliyunProxy::Pnvs::PhoneService.any_instance.stubs(:get_number).returns(nil)
    post :create, params: { phone: { sp_token: "proof" } }, format: :json

    assert_response :bad_request
    assert_predicate response.parsed_body.dig("error", "message"), :present?
  end

  test "an unstructured provider exception does not trigger another exception or disclose internals" do
    AliyunProxy::Pnvs::PhoneService.any_instance.stubs(:get_number).raises(IOError, "private provider internals")
    post :create, params: { phone: { sp_token: "proof" } }, format: :json

    assert_response :bad_request
    refute_includes response.parsed_body.dig("error", "message"), "private provider internals"
  end
end
