require "historiographer/postgres_migration"

class CreateEasyMLFeatureHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_feature_histories do |t|
      t.histories(
        foreign_key: :feature_id,
        index_names: {
          [:dataset_id, :feature_position] => "idx_feature_histories_on_dataset_and_position"
        }
      )
    end
  end
end 