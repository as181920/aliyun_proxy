module AliyunProxy
  class Captcha::ChallengesController < Captcha::BaseController
    before_action :load_challenge
    layout "aliyun_proxy/captcha"

    rescue_from Captcha::Challenge::Expired, with: :expired_challenge
    rescue_from Captcha::Challenge::BrowserMismatch, with: :browser_mismatch

    def show
      @client_options = Captcha::Configuration.client_options(scene: @challenge.attributes.fetch("scene"), certify_id: @challenge.attributes.fetch("certify_id"))
      @client_options[:language] = I18n.locale.to_s == "en" ? "en" : "cn"
      @prefix = Captcha::Configuration.prefix
      @cancel_url = @challenge.return_url(captcha_challenge: @challenge.id, captcha_status: "cancelled")
    rescue Captcha::Client::ConfigurationError, ArgumentError
      display_error("unavailable", :service_unavailable)
    end

    def update
      @challenge.verify!(parameter: params.require(:captcha).fetch(:verify_param).to_s)
      @redirect_url = @challenge.return_url(captcha_challenge: @challenge.id)
      render "verified"
    rescue Captcha::Challenge::VerificationFailed, ActionController::ParameterMissing, KeyError, ArgumentError
      render_verification_error("failed", :unprocessable_entity)
    rescue Captcha::Client::Unavailable, Captcha::Client::ConfigurationError, Captcha::Challenge::StorageUnavailable
      render_verification_error("unavailable", :service_unavailable)
    end

    private

      def load_challenge
        response.headers["Cache-Control"] = "no-store"
        response.headers["Referrer-Policy"] = "no-referrer"
        @challenge = Captcha::Challenge.find(params[:id])
        raise Captcha::Challenge::BrowserMismatch unless @challenge.browser_matches?(session[:aliyun_captcha_browser_key])
      end

      def expired_challenge
        display_error("expired", :gone)
      end

      def browser_mismatch
        display_error("browser_mismatch", :forbidden)
      end

      def display_error(kind, status)
        # rescue_from runs after the around_action has restored the locale.
        switch_locale do
          @message = t("aliyun_proxy.captcha.#{kind}")
          respond_to do |format|
            format.html { render "unavailable", status: }
            format.json { render_verification_error(kind, status) }
          end
        end
      end

      def render_verification_error(kind, status)
        @error_code = "captcha.#{kind}"
        @error_message = t("aliyun_proxy.captcha.#{kind}")
        render "error", status:
      end
  end
end
