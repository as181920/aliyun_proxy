module AliyunProxy
  class Sms::Template < ApplicationRecord
    enum :state, {
      ready: 0,
      approving: 1,
      approved: 2,
      rejected: 41,
      cancelled: 42,
      illegal: 43
    }, default: :ready

    enum :message_type, {
      unknown: 10,
      verification_code: 0,
      notification: 1,
      promotion: 2,
      international: 3,
      digital: 7
    }

    has_many :template_holder_maps, dependent: :destroy

    validates_presence_of :name, :state, :message_type, :content, :content_digest
    validates_uniqueness_of :template_code

    before_validation :calc_content_digest
    after_save_commit :sync_to_cloud
    after_destroy_commit :delete_from_cloud

    def to_s
      content
    end

    def calc_content_digest
      self.content_digest = Digest::MD5.hexdigest self.content.to_s
    end

    def holders
      template_holder_maps.map(&:holder)
    end

    def sync_to_cloud
      return if self.approved?
      return unless (self.previous_changes.keys & %w[message_type name content remark]).present?

      if template_code.present?
        Sms::CloudTemplateAddJob.perform_later(self.id)
      else
        Sms::CloudTemplateModifyJob.perform_later(self.id)
      end
    end

    def delete_from_cloud
      Sms::CloudTemplateDeleteJob.perform_later(self.template_code)
    end
  end
end

# TODO
# after_commit :update_wxpay_stock, on: :update
# after_commit :empty_wxpay_stock, on: :destroy
