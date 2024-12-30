class CreateEasyMLDatasources < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_datasources do |t|
      t.string :name, null: false
      t.string :datasource_type
      t.string :root_dir
      t.json :configuration
      t.datetime :refreshed_at

      t.timestamps
      t.index :created_at
      t.index :datasource_type
      t.index :refreshed_at
    end
  end
end