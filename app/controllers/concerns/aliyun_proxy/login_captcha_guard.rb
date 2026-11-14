module AliyunProxy
  module LoginCaptchaGuard
    extend ActiveSupport::Concern

    included do
      # A halted before_action skips the success marker; ensure still revokes proof.
      around_action :finish_login_captcha_attempt, only: :create
      after_action :record_login_captcha_success, only: :create
    end

    private

      def record_login_captcha_success
        return unless @recent_login_proof && @login_captcha_verified

        @login_captcha_succeeded = response.successful? ||
          (response.redirect? && @user.present? && authentication_session.user_id == @user.id)
      end

      def finish_login_captcha_attempt
        succeeded = false
        yield
        succeeded = @login_captcha_succeeded
      ensure
        if @recent_login_proof && @login_captcha_verified
          if succeeded
            @recent_login_proof.establish if @login_captcha_fresh
          else
            @recent_login_proof.invalidate
          end
        end
      end

      def verify_login_attempt_captcha
        return unless Captcha::Configuration.enabled?("login")

        resource = login_attempt_context.merge("path" => request.path)
        client_key = params[:captcha_client_key].presence
        if client_key
          destination = URI(Captcha::Configuration.valid_return_url(params[:captcha_return_url]))
          port = destination.port == destination.default_port ? "" : ":#{destination.port}"
          resource["client_origin"] = "#{destination.scheme}://#{destination.host}#{port}"
        end
        if client_key.blank? && request.authorization.blank?
          @recent_login_proof = Captcha::RecentLoginProof.new(session:, resource: resource.merge("origin" => request.base_url))
          if @recent_login_proof.valid?
            @login_captcha_verified = true
            return
          end
        end
        if params[:captcha_challenge].present? && Captcha::LoginAttempt.consume(id: params[:captcha_challenge],
                                                                             session:,
                                                                             resource:,
                                                                             client_key:)
          @login_captcha_verified = true
          @login_captcha_fresh = true
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
