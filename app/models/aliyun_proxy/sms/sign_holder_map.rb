module AliyunProxy
  class Sms::SignHolderMap < ApplicationRecord
    belongs_to :sign
    belongs_to :holder, polymorphic: true

    validates_presence_of :sign_id, :holder_type, :holder_id
    validates_uniqueness_of :sign_id, scope: [:holder_type, :holder_id]
  end
end
