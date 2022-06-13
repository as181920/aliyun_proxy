class CreateAliyunProxySmsTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :aliyun_sms_templates do |t|
      t.string :name, index: true
      t.integer :state
      t.integer :message_type
      t.text :content
      t.string :content_digest, index: true
      t.text :remark
      t.text :reason

      t.string :template_code, index: { unique: true }

      t.timestamps
    end
  end
end
