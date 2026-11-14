require "openssl"
require "base64"
require "securerandom"
require "uri"

module AliyunProxy
  module Captcha
    class Client
      class ConfigurationError < StandardError; end
      class Unavailable < StandardError
        attr_reader :code, :request_id

        def initialize(message = "CAPTCHA verification unavailable", code: nil, request_id: nil)
          @code = code
          @request_id = request_id
          super(message)
        end
      end

      ENDPOINT = "https://captcha.cn-shanghai.aliyuncs.com".freeze
      API_VERSION = "2023-03-05".freeze

      class << self
        def validate_parameter(parameter)
          raise ArgumentError, "Missing verification parameter" unless parameter.is_a?(String) && parameter.present? && parameter.bytesize <= 16_384
        end
      end

      def verify(parameter:, scene_id:)
        self.class.validate_parameter(parameter)

        body = URI.encode_www_form(CaptchaVerifyParam: parameter, SceneId: scene_id)
        response = Faraday.new(url: ENDPOINT, request: { open_timeout: 2, timeout: 4 }).post("/") do |request|
          request.headers.update(signed_headers(body))
          request.headers["Content-Type"] = "application/x-www-form-urlencoded"
          request.body = body
        end
        data = JSON.parse(response.body)
        raise Unavailable unless data.is_a?(Hash)
        raise Unavailable.new(code: data["Code"], request_id: data["RequestId"]) unless response.success? && data["Success"] == true && data["Result"].is_a?(Hash)

        data.fetch("Result")
      rescue Faraday::Error, JSON::ParserError, KeyError
        raise Unavailable, "CAPTCHA verification unavailable"
      end

      def encrypted_scene_id(scene_id:, lifetime: 300, now: Time.current)
        key = Base64.strict_decode64(setting("ekey"))
        raise ConfigurationError, "CAPTCHA ekey must decode to 32 bytes" unless key.bytesize == 32

        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.encrypt
        cipher.key = key
        iv = cipher.random_iv
        plaintext = [scene_id, now.to_i - 5, lifetime.to_i.clamp(1, 86_400)].join("&")
        Base64.strict_encode64(iv + cipher.update(plaintext) + cipher.final)
      rescue ArgumentError
        raise ConfigurationError, "CAPTCHA ekey is invalid"
      end

      private

        def setting(name)
          ENV["aliyun_captcha_#{name}"].to_s.presence || raise(ConfigurationError, "CAPTCHA #{name} is not configured")
        end

        def signed_headers(body)
          headers = {
            "host" => URI(ENDPOINT).host,
            "x-acs-action" => "VerifyIntelligentCaptcha",
            "x-acs-content-sha256" => Digest::SHA256.hexdigest(body),
            "x-acs-date" => Time.now.utc.iso8601,
            "x-acs-signature-nonce" => SecureRandom.hex(16),
            "x-acs-version" => API_VERSION
          }
          headers["x-acs-security-token"] = ENV["aliyun_captcha_security_token"] if ENV["aliyun_captcha_security_token"].present?
          names = headers.keys.sort
          canonical = ["POST", "/", "", names.map { |key| "#{key}:#{headers[key]}\n" }.join, names.join(";"), headers["x-acs-content-sha256"]].join("\n")
          string_to_sign = "ACS3-HMAC-SHA256\n#{Digest::SHA256.hexdigest(canonical)}"
          signature = OpenSSL::HMAC.hexdigest("SHA256", setting("access_key_secret"), string_to_sign)
          headers["Authorization"] = "ACS3-HMAC-SHA256 Credential=#{setting('access_key_id')},SignedHeaders=#{names.join(';')},Signature=#{signature}"
          headers
        end
    end
  end
end
