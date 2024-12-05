class CreateEasyMLTransforms < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_transforms do |t|
      t.bigint :dataset_id, null: false
      t.string :name
      t.string :transform_class, null: false
      t.string :transform_method, null: false
      t.integer :transform_position
      t.datetime :applied_at

      t.timestamps

      t.index %i[dataset_id transform_position], name: "idx_transforms_on_dataset_and_position"
      t.index %i[dataset_id name], unique: true, name: "idx_transforms_on_dataset_and_name"
      t.index :transform_class
      t.index :applied_at
    end
  end
end
