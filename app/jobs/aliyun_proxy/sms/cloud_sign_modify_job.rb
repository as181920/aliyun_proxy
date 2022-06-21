module AliyunProxy
  class Sms::CloudSignModifyJob < ApplicationJob
    queue_as :default

    def perform(sign_id)
      sign = Sms::Sign.find sign_id
      AliyunProxy::Sms::SignService.new(ENVConfig.aliyun_sms_access_key_id, ENVConfig.aliyun_sms_access_key_secret)
        .modify(sign)
    end
  end
end
