module AliyunProxy
  class Pnvs::VerifyScheme < ApplicationRecord
    enum :state, {
      ready: 0,
      success: 8
    }, default: :ready

    validates :scheme_name, :app_name, :os_type, presence: true

    validates :origin, :url, presence: true, if: -> { os_type == "Web" }

    validates :url, uniqueness: { scope: :os_type }, allow_blank: true
  end
end
