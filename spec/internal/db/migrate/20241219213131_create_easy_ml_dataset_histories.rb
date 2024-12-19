require "historiographer/postgres_migration"

class CreateEasyMLDatasetHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_dataset_histories do |t|
      t.histories(foreign_key: :dataset_id)
    end
  end
end 