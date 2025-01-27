require "historiographer/postgres_migration"

class CreateEasyMLDatasourceHistories < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_datasource_histories)
      create_table :easy_ml_datasource_histories do |t|
        t.histories(foreign_key: :datasource_id)
      end
    end
  end
end