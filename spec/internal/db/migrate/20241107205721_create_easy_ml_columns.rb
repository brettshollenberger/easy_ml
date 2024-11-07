class CreateEasyMLColumns < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_columns do |t|
      t.bigint :dataset_id, null: false
      t.string :name, null: false
      t.string :datatype # The symbol representation (e.g., 'float', 'integer')
      t.string :polars_datatype # The full Polars class name (e.g., 'Polars::Float64')
      t.json :preprocessing_steps
      t.boolean :is_target
      t.boolean :hidden, default: false
      t.boolean :drop_if_null, default: false
      t.json :sample_values # Store up to 3 sample values
      t.json :statistics

      t.timestamps

      t.index [:dataset_id, :name], unique: true
      t.index :datatype
      t.index :hidden
    end
  end
end 