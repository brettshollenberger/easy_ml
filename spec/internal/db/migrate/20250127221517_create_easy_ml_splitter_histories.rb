require "historiographer/postgres_migration"

class CreateEasyMLSplitterHistories < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_splitter_histories)
      create_table :easy_ml_splitter_histories do |t|
        t.histories(foreign_key: :splitter_id)
      end
    end
  end 
  end