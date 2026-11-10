require "digest"

module AliyunProxy::Captcha
  # A one-use human-verification proof; it does not authenticate a user.
  class LoginAttempt
    PURPOSE = "login_attempt".freeze

    class << self
      def issue(session:, resource:, return_url:, client_key: nil)
        browser_key = client_key.present? ? client_digest(client_key) : BrowserBinding.key(session)
        Challenge.issue(identity: browser_key,
                        scene: "login",
                        purpose: PURPOSE,
                        resource:,
                        return_url:,
                        browser_key:)
      end

      def client_challenge?(challenge)
        challenge.purpose == PURPOSE && challenge.attributes.fetch("resource").is_a?(Hash) &&
          challenge.attributes.fetch("resource")["client_origin"].present?
      end

      def client_key_matches?(challenge, key)
        client_challenge?(challenge) && key.present? && challenge.browser_matches?(client_digest(key))
      rescue ArgumentError
        false
      end

      def client_digest(key)
        raise ArgumentError, "Invalid CAPTCHA client key" unless key.is_a?(String) && key.match?(/\A[A-Za-z0-9_-]{43}\z/)

        Digest::SHA256.hexdigest("login_attempt:#{key}")
      end

      def consume(id:, session:, resource:, client_key: nil)
        browser_key = client_key.present? ? client_digest(client_key) : BrowserBinding.key(session, create: false)
        challenge = Challenge.find(id)
        challenge.browser_matches?(browser_key) &&
          challenge.consume(identity: browser_key, purpose: PURPOSE, resource:)
      rescue Challenge::Expired
        false
      end
    end
  end
end
