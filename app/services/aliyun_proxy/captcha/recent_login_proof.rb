require "digest"

module AliyunProxy::Captcha
  # Human verification only; the login endpoint still checks every credential.
  class RecentLoginProof
    LIFETIME = 2.hours

    def initialize(session:, resource:)
      browser = BrowserBinding.key(session, create: false)
      binding = resource.to_h.stringify_keys.sort.to_h.to_json
      @key = "AliyunProxy:Captcha:LoginProof:#{Digest::SHA256.hexdigest([browser, binding].join("\0"))}" if browser.present?
    end

    def valid?
      return false unless @key

      proof = Rails.cache.read(@key)
      proof.is_a?(Hash) && proof[:expires_at].is_a?(Integer) && proof[:expires_at] > Time.current.to_i
    rescue StandardError
      report_unavailable
      false
    end

    def establish
      return unless @key

      stored = Rails.cache.write(@key, { expires_at: LIFETIME.from_now.to_i }, expires_in: LIFETIME)
      raise Challenge::StorageUnavailable unless stored
    rescue StandardError
      report_unavailable
      nil
    end

    def invalidate
      Rails.cache.delete(@key) if @key
    rescue StandardError
      report_unavailable
      nil
    end

    private

      def report_unavailable
        Rails.logger.warn("CAPTCHA recent login proof cache unavailable")
      rescue StandardError
        nil
      end
  end
end
