class CreateEasyMLSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_settings do |t|
      t.string :storage
      t.string :timezone
      t.string :s3_access_key_id
      t.string :s3_secret_access_key
      t.string :s3_bucket
      t.string :s3_region
      t.string :s3_prefix

      t.timestamps
    end
  end
end 