require "historiographer/postgres_migration"

class CreateEasyMLLineages < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_lineages)
      create_table :easy_ml_lineages do |t|
        t.bigint :column_id, null: false
        t.string :key, null: false
        t.string :description
        t.datetime :occurred_at

        t.timestamps
        
        t.index :column_id
        t.index :key
        t.index :occurred_at
      end

      create_table :easy_ml_lineage_histories do |t|
        t.histories
      end
    end
  end
end
