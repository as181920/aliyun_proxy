require "test_helper"

class AliyunProxy::Captcha::RecentLoginProofTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @session = ActionController::TestSession.new
    AliyunProxy::Captcha::BrowserBinding.key(@session)
    @resource = { "origin" => "https://www.example.com", "path" => "/tenant_auth/sessions", "name" => "account" }
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "missing proof requires verification" do
    refute_predicate proof, :valid?
  end

  test "a recorded successful login provides a two hour human proof" do
    proof.establish
    travel 90.minutes

    assert_predicate proof, :valid?
  end

  test "reuse is not limited to five logins" do
    proof.establish

    10.times { assert_predicate proof, :valid? }
  end

  test "reading proof never extends its original expiry" do
    proof.establish
    travel 119.minutes
    proof.valid?
    travel 2.minutes

    refute_predicate proof, :valid?
  end

  test "expiry is enforced at the exact two hour boundary" do
    proof.establish
    travel 2.hours

    refute_predicate proof, :valid?
  end

  %w[name path tenant_uid organization_uid origin].each do |dimension|
    test "a different #{dimension} cannot reuse proof" do
      proof.establish

      refute_predicate proof(resource: @resource.merge(dimension => "different")), :valid?
    end
  end

  test "a different browser cannot reuse proof" do
    proof.establish
    other_session = ActionController::TestSession.new
    AliyunProxy::Captcha::BrowserBinding.key(other_session)

    refute_predicate AliyunProxy::Captcha::RecentLoginProof.new(session: other_session, resource: @resource), :valid?
  end

  test "context key ordering does not change the proof's binding" do
    proof.establish

    assert_predicate proof(resource: @resource.to_a.reverse.to_h), :valid?
  end

  test "failed credentials can revoke an existing proof" do
    proof.establish
    proof.invalidate

    refute_predicate proof, :valid?
  end

  test "sign out can clear identity without removing independent human proof" do
    @session[:tnt_user_id] = 10
    proof.establish
    @session.delete(:tnt_user_id)

    assert_predicate proof, :valid?
    assert_empty @session.to_hash
  end

  test "a client without a stable session never establishes reusable proof" do
    value = AliyunProxy::Captcha::RecentLoginProof.new(session: Struct.new(:id).new(nil), resource: @resource)
    value.establish

    refute_predicate value, :valid?
  end

  test "cache read failure requires fresh verification" do
    proof.establish
    Rails.cache.stubs(:read).raises(IOError)

    refute_predicate proof, :valid?
  end

  test "a cache write failure cannot grant proof" do
    Rails.cache.stubs(:write).returns(false)
    proof.establish

    refute_predicate proof, :valid?
  end

  test "proof storage never calls the provider or needs an Auth engine" do
    AliyunProxy::Captcha::Client.expects(:new).never
    proof.establish

    assert_predicate proof, :valid?
    assert_nil defined?(TenantAuth::Engine)
  end

  private

    def proof(resource: @resource)
      AliyunProxy::Captcha::RecentLoginProof.new(session: @session, resource:)
    end
end
