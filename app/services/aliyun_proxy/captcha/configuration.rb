module AliyunProxy::Captcha
  class Configuration
    class << self
      def scene_id(scene)
        ENV["aliyun_captcha_#{scene}_scene_id"].to_s.presence || raise(AliyunProxy::Captcha::Client::ConfigurationError, "CAPTCHA scene is not configured")
      end

      def enabled?(scene)
        ActiveModel::Type::Boolean.new.cast(ENV["aliyun_captcha_#{scene}_enabled"]) == true
      end

      def prefix
        ENV["aliyun_captcha_prefix"].to_s.presence || raise(AliyunProxy::Captcha::Client::ConfigurationError, "CAPTCHA prefix is not configured")
      end

      def client_options(scene:, certify_id:)
        scene = scene_id(scene)
        options = { SceneId: scene, UserCertifyId: certify_id }
        if enabled?("encryption")
          options[:EncryptedSceneId] = AliyunProxy::Captcha::Client.new.encrypted_scene_id(scene_id: scene)
        end
        options
      end

      def base_url
        value = ENV["aliyun_captcha_base_url"].to_s.presence || ENV["app_frontend_base_url"].to_s
        uri = valid_url(value)
        raise ArgumentError, "CAPTCHA base URL must be an origin" unless origin_only?(uri)

        origin(uri)
      end

      def valid_return_url(value)
        uri = valid_url(value, allow_http_loopback: true)
        origins = ENV.fetch("aliyun_captcha_return_origins", "").split(",").map(&:strip)
        origins << origin(URI(base_url))
        raise ArgumentError, "Return URL origin is not allowed" unless origins.any? { |allowed| matches_origin?(uri, allowed) }

        uri.to_s
      end

      private

        def matches_origin?(uri, value)
          allowed = URI.parse(value)
          return false unless origin_only?(allowed) && uri.scheme == allowed.scheme && uri.port == allowed.port

          host = uri.host.downcase
          allowed_host = allowed.host.to_s.downcase
          return host == allowed_host unless allowed_host.start_with?("*.")

          suffix = allowed_host.delete_prefix("*")
          host.end_with?(suffix) && host.delete_suffix(suffix).match?(/\A[a-z0-9-]+(?:\.[a-z0-9-]+)*\z/)
        rescue URI::InvalidURIError
          false
        end

        def origin_only?(uri)
          uri.userinfo.nil? && [nil, "", "/"].include?(uri.path) && uri.query.nil? && uri.fragment.nil?
        end

        def valid_url(value, allow_http_loopback: !Rails.env.production?)
          uri = URI.parse(value.to_s)
          valid = uri.is_a?(URI::HTTPS) || (allow_http_loopback && uri.is_a?(URI::HTTP) && %w[localhost 127.0.0.1].include?(uri.host))
          raise ArgumentError, "An absolute HTTPS URL is required" unless valid && uri.host.present? && uri.userinfo.nil?

          uri
        rescue URI::InvalidURIError
          raise ArgumentError, "Invalid URL"
        end

        def origin(uri)
          "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
        end
    end
  end
end
