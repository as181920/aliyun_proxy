module AliyunProxy
  class Sms::CloudTemplateAddJob < ApplicationJob
    queue_as :default

    def perform(template_id)
      template = Sms::Template.find template_id
      AliyunProxy::Sms::TemplateService.new(ENVConfig.aliyun_sms_access_key_id, ENVConfig.aliyun_sms_access_key_secret)
        .add(template)
    end
  end
end
