require "historiographer/postgres_migration"

class CreateEasyMLFeatureHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_feature_histories do |t|
      t.histories(foreign_key: :feature_id)
    end
  end
end 