class CreateAliyunProxyPnvsVerifySchemes < ActiveRecord::Migration[7.1]
  def change
    create_table :aliyun_pnvs_verify_schemes do |t|
      t.string :scheme_name
      t.string :app_name
      t.string :os_type
      t.string :origin
      t.string :url

      t.integer :state
      t.string :scheme_code

      t.timestamps
    end
  end
end
