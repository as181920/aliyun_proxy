module AliyunProxy
  class Sms::CloudTemplateModifyJob < ApplicationJob
    queue_as :default

    def perform(template_id)
      template = Sms::Template.find template_id
      AliyunProxy::Sms::TemplateService.new(ENVConfig.aliyun_sms_access_key_id, ENVConfig.aliyun_sms_access_key_secret)
        .modify(template)
    end
  end
end
