module AliyunProxy
  module Sms
    module Holdable
      extend ActiveSupport::Concern

      included do
        has_many :aliyun_sms_sign_holder_maps, class_name: "::AliyunProxy::Sms::SignHolderMap", as: :holder
        has_many :aliyun_sms_signs, class_name: "::AliyunProxy::Sms::Sign", through: :aliyun_sms_sign_holder_maps, source: :sign

        has_many :aliyun_sms_template_holder_maps, class_name: "::AliyunProxy::Sms::TemplateHolderMap", as: :holder
        has_many :aliyun_sms_templates, class_name: "::AliyunProxy::Sms::Template", through: :aliyun_sms_template_holder_maps, source: :template
      end
    end
  end
end
