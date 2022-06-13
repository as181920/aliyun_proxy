module AliyunProxy
  class Sms::TemplateHolderMap < ApplicationRecord
    belongs_to :template
    belongs_to :holder, polymorphic: true

    validates_presence_of :template_id, :holder_type, :holder_id
    validates_uniqueness_of :template_id, scope: [:holder_type, :holder_id]
  end
end
