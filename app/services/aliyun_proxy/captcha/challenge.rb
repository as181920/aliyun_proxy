module AliyunProxy::Captcha
  class Challenge
    class Expired < StandardError; end
    class VerificationFailed < StandardError; end
    class StorageUnavailable < StandardError; end
    class BrowserMismatch < StandardError; end
    LIFETIME = 10.minutes

    attr_reader :id, :attributes

    class << self
      def issue(identity:, scene:, purpose:, resource:, return_url:, browser_key: nil)
        raise ArgumentError, "Verification identity and purpose are required" if identity.blank? || scene.blank? || purpose.blank?

        id = SecureRandom.urlsafe_base64(32)
        attributes = {
          "identity" => identity.to_s, "browser_key" => browser_key, "state" => "issued", "purpose" => purpose, "resource" => resource,
          "return_url" => Configuration.valid_return_url(return_url),
          "scene" => scene.to_s, "scene_id" => Configuration.scene_id(scene),
          "certify_id" => "#{Configuration.prefix}_#{SecureRandom.alphanumeric(10)}",
          "expires_at" => LIFETIME.from_now.to_i
        }
        raise StorageUnavailable unless Rails.cache.write(key(id), attributes, expires_in: LIFETIME)

        new(id, attributes)
      end

      def find(id)
        raise Expired unless id.to_s.match?(/\A[A-Za-z0-9_-]{43}\z/)

        attributes = Rails.cache.read(key(id))
        raise Expired unless attributes && attributes.fetch("expires_at") > Time.current.to_i && attributes["state"] != "revoked"

        new(id, attributes)
      end

      def key(id)
        "AliyunProxy:Captcha:Challenge:#{id}"
      end
    end

    def initialize(id, attributes)
      @id = id
      @attributes = attributes
    end

    def revoke
      stored = with_state_lock do
        current = self.class.find(id)
        next true if current.consumed?

        Rails.cache.write(self.class.key(id), current.attributes.merge("state" => "revoked"), expires_in: remaining)
      end
      raise StorageUnavailable unless stored

      true
    rescue Expired
      false
    end

    def identity
      attributes.fetch("identity")
    end

    def purpose
      attributes.fetch("purpose")
    end

    def return_url(**query)
      uri = URI(attributes.fetch("return_url"))
      uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s).reject { |key, _| query.key?(key.to_sym) } + query.map { |k, v| [k, v] })
      uri.to_s
    end

    def browser_matches?(key)
      expected = attributes["browser_key"]
      expected.present? && key.present? && ActiveSupport::SecurityUtils.secure_compare(expected, key)
    end

    def bind_browser(key:)
      raise BrowserMismatch if key.blank?

      stored = with_state_lock do
        current = self.class.find(id)
        raise Expired unless current.attributes["state"].in?(%w[issued verified])
        raise BrowserMismatch if current.attributes["browser_key"].present? && !current.browser_matches?(key)

        Rails.cache.write(self.class.key(id), current.attributes.merge("browser_key" => key), expires_in: remaining)
      end
      raise StorageUnavailable unless stored

      @attributes = attributes.merge("browser_key" => key)
      self
    end

    def verify(parameter:)
      raise VerificationFailed if consumed?
      return true if verified?

      result = AliyunProxy::Captcha::Client.new.verify(parameter:, scene_id: attributes.fetch("scene_id"))
      passed = result["VerifyResult"] == true && result["VerifyCode"] == "T001" &&
        result["CertifyId"].to_s == attributes.fetch("certify_id")
      raise VerificationFailed unless passed
      stored = with_state_lock do
        current = self.class.find(id)
        raise VerificationFailed if current.consumed?

        Rails.cache.write(self.class.key(id), current.attributes.merge("state" => "verified"), expires_in: remaining)
      end
      raise StorageUnavailable unless stored

      true
    end

    def consume(identity:, purpose:, resource:)
      match = identity.to_s == self.identity && purpose == self.purpose && resource == attributes.fetch("resource")
      return false unless match && verified? && attributes.fetch("expires_at") > Time.current.to_i

      with_state_lock do
        current = self.class.find(id)
        next false unless current.attributes["state"] == "verified"

        Rails.cache.write(self.class.key(id), current.attributes.merge("state" => "consumed"), expires_in: remaining) == true
      end
    rescue Expired
      false
    end

    def verified?
      Rails.cache.read(self.class.key(id))&.dig("state") == "verified"
    end

    def consumed?
      Rails.cache.read(self.class.key(id))&.dig("state") == "consumed"
    end

    private

      def remaining
        [attributes.fetch("expires_at") - Time.current.to_i, 1].max
      end

      # A single cache value prevents partial eviction from resurrecting a consumed
      # authorization. No vendor request runs while the non-waiting lock is held.
      def with_state_lock(&block)
        ActiveRecord::Base.with_advisory_lock("aliyun_proxy:captcha:#{id}", timeout_seconds: 0) do
          Rails.cache.with_local_cache(&block)
        end
      end
  end
end
