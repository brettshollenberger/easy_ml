class CreateEasyMLFeatures < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_features do |t|
      t.bigint :dataset_id, null: false
      t.string :name
      t.bigint :version
      t.string :feature_class, null: false
      t.integer :feature_position
      t.integer :batch_size
      t.boolean :needs_fit
      t.string :sha
      t.string :primary_key, array: true
      t.datetime :applied_at
      t.datetime :fit_at
      t.bigint :refresh_every

      t.timestamps

      t.index %i[dataset_id feature_position], name: "idx_features_on_dataset_and_position"
      t.index %i[dataset_id name], unique: true, name: "idx_features_on_dataset_and_name"
      t.index :feature_class
      t.index :applied_at
      t.index :name
      t.index :version
      t.index :sha
      t.index :batch_size
      t.index :needs_fit
      t.index :fit_at
      t.index :refresh_every
    end
  end
end
