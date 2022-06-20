module AliyunProxy
  class Sms::TemplateHolderMap < ApplicationRecord
    belongs_to :template
    belongs_to :holder, polymorphic: true

    validates_presence_of :template_id, :holder_type, :holder_id
    validates_uniqueness_of :template_id, scope: [:holder_type, :holder_id]

    after_destroy_commit :clean_holderless_template

    private

      def clean_holderless_template
        template.destroy if template.template_holder_maps.where.not(holder: self).empty?
      end
  end
end
