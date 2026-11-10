module AliyunProxy
  class Captcha::ChallengesController < Captcha::BaseController
    skip_forgery_protection if: -> { action_name == "update" && client_key_matches? }

    before_action :load_challenge
    content_security_policy only: :show, if: -> { @client_origin.present? } do |policy|
      policy.frame_ancestors :self, @client_origin
    end
    layout "aliyun_proxy/captcha"


    def show
      @client_options = Captcha::Configuration.client_options(scene: @challenge.attributes.fetch("scene"), certify_id: @challenge.attributes.fetch("certify_id"))
      @client_options[:language] = I18n.locale.to_s == "en" ? "en" : "cn"
      @prefix = Captcha::Configuration.prefix
      @cancel_url = @challenge.return_url(captcha_challenge: @challenge.id, captcha_status: "cancelled")
    rescue Captcha::Client::ConfigurationError, ArgumentError
      display_error("unavailable", :service_unavailable)
    end

    def update
      @challenge.verify(parameter: params.require(:captcha).fetch(:verify_param).to_s)
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
        if Captcha::LoginAttempt.client_challenge?(@challenge)
          @client_origin = @challenge.attributes.fetch("resource").fetch("client_origin")
          response.headers.delete("X-Frame-Options") if action_name == "show"
          raise Captcha::Challenge::BrowserMismatch if action_name == "update" && !client_key_matches?
        else
          raise Captcha::Challenge::BrowserMismatch unless @challenge.browser_matches?(Captcha::BrowserBinding.key(session, create: false))
        end
      end

      def client_key_matches?
        key = request.headers["X-Captcha-Client-Key"]
        return false if key.blank?

        challenge = Captcha::Challenge.find(params[:id])
        Captcha::LoginAttempt.client_key_matches?(challenge, key)
      rescue Captcha::Challenge::Expired
        false
      end
  end
end
