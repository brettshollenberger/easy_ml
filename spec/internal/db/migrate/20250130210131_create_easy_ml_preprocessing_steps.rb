class CreateEasyMLPreprocessingSteps < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_preprocessing_steps)
      create_table :easy_ml_preprocessing_steps do |t|
        t.string :method, null: false
        t.jsonb :params, null: false
        t.bigint :column_id
        t.timestamps

        t.index :method
        t.index :column_id
        t.index :created_at
      end

      remove_column :easy_ml_columns, :preprocessing_steps
    end
  end
end