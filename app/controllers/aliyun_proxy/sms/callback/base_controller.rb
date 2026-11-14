module AliyunProxy
  class Sms::Callback::BaseController < ApplicationController
    # Cloud callbacks optionally use an explicit secret, never browser authentication.
    skip_forgery_protection only: :create
    before_action :authenticate_callback, only: %i[index create]

    def index
      render "aliyun_proxy/sms/callback/acknowledged", formats: :json, status: :ok
    end

    private

      def authenticate_callback
        secret = ENV["aliyun_sms_callback_token"]
        return if secret.blank?

        supplied = request.query_parameters["callback_token"]
        if secret.bytesize < 32
          callback_error(:service_unavailable)
        elsif !supplied.is_a?(String) || !ActiveSupport::SecurityUtils.secure_compare(secret, supplied)
          callback_error(:unauthorized)
        end
      end

      def callback_error(status)
        @error_message = t("aliyun_proxy.flash.callback_authentication_failed")
        render "aliyun_proxy/shared/error", formats: :json, status:
      end
  end
end
