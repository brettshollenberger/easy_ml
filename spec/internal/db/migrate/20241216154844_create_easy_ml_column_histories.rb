require "historiographer/postgres_migration"

class CreateEasyMLColumnHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_column_histories do |t|
      t.histories(foreign_key: :column_id)
    end
  end
end 