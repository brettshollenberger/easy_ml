class CreateEasyMLDatasets < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_datasets do |t|
      t.string :name, null: false
      t.bigint :datasource_id
      t.json :configuration

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :datasource_id
    end
  end
end