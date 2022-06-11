module AliyunProxy
  class Sms::Callback::SignReportsController < ApplicationController
    def create
      render json: { code: 0, msg: "成功" }, status: :ok
    end
  end
end
