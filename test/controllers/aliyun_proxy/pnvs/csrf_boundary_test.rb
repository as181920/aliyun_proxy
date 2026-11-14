require "test_helper"

class AliyunProxy::Pnvs::CsrfBoundaryTest < ActionController::TestCase
  tests AliyunProxy::Pnvs::AuthTokensController

  setup do
    @routes = AliyunProxy::Engine.routes
    @previous_protection = @controller.class.allow_forgery_protection
    @controller.class.allow_forgery_protection = true
    @user = Struct.new(:id).new(123)
    @credential = stub(user: @user, regenerate_code: true)
    @credentials = mock
    @controller.stubs(:credential_model).returns(@credentials)
    AliyunProxy::Pnvs::AuthTokenService.any_instance.stubs(:generate).returns({ "Code" => "OK" })
  end

  teardown do
    @controller.class.allow_forgery_protection = @previous_protection
  end

  test "a JSON browser request cannot bypass CSRF using its format" do
    session[:usr_user_id] = @user.id

    assert_raises(ActionController::InvalidAuthenticityToken) { post :create, format: :json }
  end

  test "Basic authentication retains the browser CSRF boundary" do
    @request.headers["Authorization"] = "Basic placeholder"

    assert_raises(ActionController::InvalidAuthenticityToken) { post :create, format: :json }
  end

  test "an explicit token API needs no CSRF token and does not establish browser identity" do
    @request.headers["Authorization"] = "PlainUserToken token"
    @credentials.expects(:find_by).with(token: "token").returns(@credential)
    post :create, format: :json

    assert_response :success
    assert_equal "OK", response.parsed_body.fetch("Code")
    assert_nil session[:usr_user_id]
  end

  test "a one use code API retains its credential exchange without CSRF" do
    @request.headers["Authorization"] = "PlainUserCode code"
    @credentials.expects(:find_by).with(code: "code").returns(@credential)
    @credential.expects(:regenerate_code)
    post :create, format: :json

    assert_response :success
    assert_nil session[:usr_user_id]
  end

  test "an invalid explicit token never falls back to the browser account" do
    session[:usr_user_id] = @user.id
    @request.headers["Authorization"] = "PlainUserToken invalid"
    @credentials.expects(:find_by).with(token: "invalid").returns(nil)
    @controller.expects(:session_user).never
    post :create, format: :json

    assert_response :unauthorized
  end

  test "browser CSRF rejection happens before a one use credential can rotate" do
    @request.headers["Authorization"] = "Basic placeholder"
    @credentials.expects(:find_by).never

    assert_raises(ActionController::InvalidAuthenticityToken) { post :create, format: :json }
  end

  test "an explicit query token retains the existing non-browser API protocol" do
    @credentials.expects(:find_by).with(token: "token").returns(@credential)
    @request.query_string = "auth_token=token"
    AliyunProxy::Pnvs::AuthTokenService.any_instance.expects(:generate).with(url: "https://app.example.com").returns({ "Code" => "OK" })
    post :create, params: { auth_token: { url: "https://app.example.com" } }, format: :json

    assert_response :success
    assert_nil session[:usr_user_id]
  end

  test "a provider error returns the standard JSON envelope" do
    @request.headers["Authorization"] = "PlainUserToken token"
    @credentials.expects(:find_by).with(token: "token").returns(@credential)
    AliyunProxy::Pnvs::AuthTokenService.any_instance.stubs(:generate).raises(IOError, "provider unavailable")
    post :create, format: :json

    assert_response :bad_request
    assert_predicate response.parsed_body.dig("error", "message"), :present?
  end
end
