class UpdatePreprocessingStepsToJsonb < ActiveRecord::Migration[7.0]
  def up
    execute 'ALTER TABLE easy_ml_columns ALTER COLUMN preprocessing_steps TYPE jsonb USING preprocessing_steps::jsonb'
    execute 'ALTER TABLE easy_ml_column_histories ALTER COLUMN preprocessing_steps TYPE jsonb USING preprocessing_steps::jsonb'
    
    # Add GIN index for efficient JSON path operations
    add_index :easy_ml_columns, :preprocessing_steps, using: :gin, name: 'index_easy_ml_columns_on_preprocessing_steps_gin'
    add_index :easy_ml_column_histories, :preprocessing_steps, using: :gin, name: 'index_easy_ml_column_histories_on_preprocessing_steps_gin'
  end

  def down
    remove_index :easy_ml_columns, name: 'index_easy_ml_columns_on_preprocessing_steps_gin'
    execute 'ALTER TABLE easy_ml_columns ALTER COLUMN preprocessing_steps TYPE json USING preprocessing_steps::json'

    remove_index :easy_ml_column_histories, name: 'index_easy_ml_column_histories_on_preprocessing_steps_gin'
    execute 'ALTER TABLE easy_ml_column_histories ALTER COLUMN preprocessing_steps TYPE json USING preprocessing_steps::json'
  end
end
