module AliyunProxy
  class Captcha::BaseController < ActionController::Base
    protect_from_forgery with: :exception
    include LocaleGuard

    rescue_from Captcha::Challenge::Expired, with: -> { display_error("expired", :gone) }
    rescue_from Captcha::Challenge::BrowserMismatch, with: -> { display_error("browser_mismatch", :forbidden) }
    rescue_from Captcha::Challenge::StorageUnavailable, with: -> { display_error("unavailable", :service_unavailable) }

    helper EasyStyle::Engine.helpers

    private

      def display_error(kind, status)
        # rescue_from runs after the around_action has restored the locale.
        switch_locale do
          @message = t("aliyun_proxy.captcha.#{kind}")
          respond_to do |format|
            format.html { render "aliyun_proxy/captcha/challenges/unavailable", status: }
            format.json { render_verification_error(kind, status) }
          end
        end
      end

      def render_verification_error(kind, status)
        @error_code = "captcha.#{kind}"
        @error_message = t("aliyun_proxy.captcha.#{kind}")
        render "aliyun_proxy/captcha/challenges/error", status:
      end
  end
end
