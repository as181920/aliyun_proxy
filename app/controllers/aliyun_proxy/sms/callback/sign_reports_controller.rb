module AliyunProxy
  class Sms::Callback::SignReportsController < ApplicationController
    after_action :handle_sign_state_change, only: [:create]

    def create
      render json: { code: 0, msg: "成功" }, status: :ok
    end

    private

      def handle_sign_state_change
        params["_json"].each do |report_info|
          Sms::Sign.find_by(name: report_info["sign_name"])&.then do |sign|
            sign.update \
              state: report_info["sign_status"],
              reason: report_info["reason"]
          end
        end
      end
  end
end
