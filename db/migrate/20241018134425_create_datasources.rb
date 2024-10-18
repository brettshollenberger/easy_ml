class CreateDatasources < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_datasources do |t|
      t.string :name, null: false
      t.string :type, null: false
      t.string :root_dir
      t.jsonb :polars_args
      t.jsonb :config
      t.jsonb :metadata
      t.timestamps
    end

    add_index :easy_ml_datasources, :name, unique: true
    add_index :easy_ml_datasources, :type
  end
end
