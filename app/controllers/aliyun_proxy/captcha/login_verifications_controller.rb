module AliyunProxy
  class Captcha::LoginVerificationsController < Captcha::BaseController
    layout "aliyun_proxy/captcha"

    rescue_from Captcha::Challenge::VerificationFailed, with: -> { display_error("failed", :forbidden) }

    def show
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      @challenge = Captcha::Challenge.find(params[:captcha_challenge])
      raise Captcha::Challenge::VerificationFailed unless @challenge.purpose == Captcha::LoginAttempt::PURPOSE
      raise Captcha::Challenge::BrowserMismatch unless @challenge.browser_matches?(Captcha::BrowserBinding.key(session, create: false))

      @cancelled = params[:captcha_status] == "cancelled"
      raise Captcha::Challenge::VerificationFailed unless @cancelled || @challenge.verified?
    end
  end
end
