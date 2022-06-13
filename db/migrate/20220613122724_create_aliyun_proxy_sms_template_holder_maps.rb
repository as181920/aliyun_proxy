class CreateAliyunProxySmsTemplateHolderMaps < ActiveRecord::Migration[7.0]
  def change
    create_table :aliyun_sms_template_holder_maps do |t|
      t.belongs_to :template
      t.belongs_to :holder, polymorphic: true

      t.datetime :created_at

      t.index [:template_id, :holder_id, :holder_type], unique: true, name: "index_alisms_template_holder_maps_on_tmpl_and_holder"
    end
  end
end
