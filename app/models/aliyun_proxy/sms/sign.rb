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
      unknown: 10,
      enterprise_name: 0,
      website_name: 1,
      app_name: 2,
      wechat_name: 3,
      e_commerce_name: 4,
      brand_name: 5
    }, default: :unknown

    validates_presence_of :state, :source_type
    validates :name, presence: true, uniqueness: true
  end
end
