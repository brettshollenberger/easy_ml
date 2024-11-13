class CreateEasyMLTransforms < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_transforms do |t|
      t.bigint :dataset_id, null: false
      t.string :transform_class, null: false
      t.string :transform_method, null: false
      t.json :parameters
      t.integer :position
      t.datetime :applied_at

      t.timestamps

      t.index [:dataset_id, :position]
      t.index :transform_class
      t.index :applied_at
    end
  end
end 