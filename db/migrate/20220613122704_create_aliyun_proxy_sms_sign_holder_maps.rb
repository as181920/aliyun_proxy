class CreateAliyunProxySmsSignHolderMaps < ActiveRecord::Migration[7.0]
  def change
    create_table :aliyun_sms_sign_holder_maps do |t|
      t.belongs_to :sign
      t.belongs_to :holder, polymorphic: true

      t.datetime :created_at

      t.index [:sign_id, :holder_id, :holder_type], unique: true, name: "index_alisms_sign_holder_maps_on_sign_and_holder"
    end
  end
end
