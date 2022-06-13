class CreateAliyunProxySmsSigns < ActiveRecord::Migration[7.0]
  def change
    create_table :aliyun_sms_signs do |t|
      t.string :name, index: { unique: true }
      t.integer :state
      t.integer :source_type
      t.text :remark
      t.jsonb :file_list
      t.text :reason

      t.timestamps
    end
  end
end
