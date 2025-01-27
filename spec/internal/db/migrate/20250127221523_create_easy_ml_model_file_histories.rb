require "historiographer/postgres_migration"

class CreateEasyMLModelFileHistories < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_model_file_histories)
      create_table :easy_ml_model_file_histories do |t|
        t.histories(foreign_key: :model_file_id)
      end
    end
  end
end