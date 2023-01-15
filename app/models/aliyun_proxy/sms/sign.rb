module AliyunProxy
  class Sms::Sign < ApplicationRecord
    enum :state, {
      ready: 0,
      approving: 1,
      approved: 2,
      rejected: 41,
      cancelled: 42,
      illegal: 43
    }, default: :ready

    enum :source_type, {
      enterprise_name: 0,
      website_name: 1,
      app_name: 2,
      wechat_name: 3,
      e_commerce_name: 4,
      brand_name: 5
    }, default: :enterprise_name

    has_many :sign_holder_maps, dependent: :destroy

    validates_presence_of :state, :source_type
    validates :name, presence: true, uniqueness: true

    after_save_commit :sync_to_cloud

    def to_s
      name
    end

    def holders
      sign_holder_maps.map(&:holder)
    end

    def sync_to_cloud
      return if self.approved? || (self.previous_changes.keys & %w[source_type name remark file_list]).blank?

      if ready?
        Sms::CloudSignAddJob.perform_later(self.id)
      else
        self.approving! and Sms::CloudSignModifyJob.perform_later(self.id)
      end
    end
  end
end
