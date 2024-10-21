class CreateEasyMLDatasets < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_datasets do |t|
      t.string :name
      t.string :root_dir
      t.jsonb :datasource
      t.jsonb :splitter
      t.jsonb :preprocessing_steps
      t.timestamps

      t.index :created_at
      t.index :name, unique: true
    end
  end
end