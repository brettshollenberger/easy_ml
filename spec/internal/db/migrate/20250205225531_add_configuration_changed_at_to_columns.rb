class AddConfigurationChangedAtToColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :configuration_changed_at, :timestamp
    add_column :easy_ml_column_histories, :configuration_changed_at, :timestamp

    add_index :easy_ml_columns, :configuration_changed_at
    add_index :easy_ml_column_histories, :configuration_changed_at
  end
end
