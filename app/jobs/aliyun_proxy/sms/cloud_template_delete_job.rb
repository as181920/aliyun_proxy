module AliyunProxy
  class Sms::CloudTemplateDeleteJob < ApplicationJob
    queue_as :batch

    def perform(template_code)
      AliyunProxy::Sms::TemplateService.new(ENVConfig.aliyun_sms_access_key_id, ENVConfig.aliyun_sms_access_key_secret)
        .delete(template_code)
    end
  end
end
