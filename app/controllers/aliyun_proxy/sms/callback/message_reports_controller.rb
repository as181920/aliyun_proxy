module AliyunProxy
  class Sms::Callback::MessageReportsController < Sms::Callback::BaseController
    def create
      render "aliyun_proxy/sms/callback/acknowledged", formats: :json
    end
  end
end
