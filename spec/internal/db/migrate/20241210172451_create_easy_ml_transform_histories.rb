require "historiographer/postgres_migration"

class CreateEasyMLTransformHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_transform_histories do |t|
      t.histories(foreign_key: :transform_id)
    end
  end
end 