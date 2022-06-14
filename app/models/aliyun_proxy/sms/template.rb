module AliyunProxy
  class Sms::Template < ApplicationRecord
    before_validation :calc_content_digest

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

    def to_s
      content
    end

    def calc_content_digest
      self.content_digest = Digest::MD5.hexdigest self.content.to_s
    end

    def holders
      template_holder_maps.map(&:holder)
    end
  end
end
