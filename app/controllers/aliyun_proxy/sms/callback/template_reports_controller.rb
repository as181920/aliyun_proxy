module AliyunProxy
  class Sms::Callback::TemplateReportsController < ApplicationController
    def create
      render json: { code: 0, msg: "成功" }, status: :ok
    end
  end
end
