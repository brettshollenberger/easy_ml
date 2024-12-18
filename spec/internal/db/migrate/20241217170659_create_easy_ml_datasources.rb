class CreateEasyMLDatasources < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_datasources do |t|
      t.string :name, null: false
      t.string :datasource_type
      t.string :root_dir
      t.json :configuration

      t.timestamps
      t.index :created_at
      t.index :datasource_type
    end
  end
end