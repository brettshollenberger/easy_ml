class CreateEasyMLFeatures < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_features do |t|
      t.bigint :dataset_id, null: false
      t.string :name
      t.bigint :version
      t.string :feature_class, null: false
      t.integer :feature_position
      t.datetime :applied_at

      t.timestamps

      t.index %i[dataset_id feature_position], name: "idx_features_on_dataset_and_position"
      t.index %i[dataset_id name], unique: true, name: "idx_features_on_dataset_and_name"
      t.index :feature_class
      t.index :applied_at
      t.index :name
      t.index :version
    end
  end
end
