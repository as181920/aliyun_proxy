module AliyunProxy
  class Sms::Callback::SignReportsController < Sms::Callback::BaseController
    def create
      handle_sign_state_change
      render "aliyun_proxy/sms/callback/acknowledged", formats: :json
    end

    private

      def handle_sign_state_change
        params.require(:_json).each do |report_info|
          Sms::Sign.find_by(name: report_info["sign_name"])&.then do |sign|
            sign.update \
              state: report_info["sign_status"],
              reason: report_info["reason"]
          end
        end
      end
  end
end
