module AliyunProxy
  module LoginCaptchaGuard
    extend ActiveSupport::Concern

    private

      def verify_login_attempt_captcha
        return unless Captcha::Configuration.enabled?("login")

        resource = login_captcha_context.merge("path" => request.path)
        client_key = params[:captcha_client_key].presence
        if client_key
          destination = URI(Captcha::Configuration.valid_return_url(params[:captcha_return_url]))
          port = destination.port == destination.default_port ? "" : ":#{destination.port}"
          resource["client_origin"] = "#{destination.scheme}://#{destination.host}#{port}"
        end
        if params[:captcha_challenge].present? && Captcha::LoginAttempt.consume(id: params[:captcha_challenge],
                                                                             session:,
                                                                             resource:,
                                                                             client_key:)
          @login_captcha_verified = true
          return
        end

        @captcha_challenge = Captcha::LoginAttempt.issue(session:,
                                                       resource:,
                                                       return_url: aliyun_proxy.captcha_login_verification_url(host: request.base_url, locale: I18n.locale),
                                                       client_key:)
        @captcha_challenge_url = aliyun_proxy.captcha_challenge_url(@captcha_challenge.id, host: request.base_url, locale: I18n.locale)
        respond_to do |format|
          format.json { render "aliyun_proxy/captcha/challenges/required", status: :unprocessable_content }
          format.any(:html, :turbo_stream) do
            render "aliyun_proxy/captcha/login_verifications/required",
                   layout: "easy_style/common",
                   formats: :html,
                   status: :unprocessable_content
          end
        end
      rescue Captcha::Challenge::StorageUnavailable,
             Captcha::Client::ConfigurationError,
             ArgumentError
        @error_code = "captcha.unavailable"
        @error_message = @message = t("aliyun_proxy.captcha.unavailable")
        respond_to do |format|
          format.json { render "aliyun_proxy/captcha/challenges/error", status: :service_unavailable }
          format.any(:html, :turbo_stream) do
            render "aliyun_proxy/captcha/challenges/unavailable",
                   layout: "aliyun_proxy/captcha",
                   formats: :html,
                   status: :service_unavailable
          end
        end
      end
  end
end
