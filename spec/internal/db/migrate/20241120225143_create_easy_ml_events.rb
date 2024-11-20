class CreateEasyMLEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_events do |t|
      t.string :name, null: false
      t.string :status, null: false
      t.string :eventable_type
      t.bigint :eventable_id
      t.text :stacktrace

      t.timestamps

      t.index :name
      t.index :status
      t.index :eventable_type
      t.index :eventable_id
      t.index :created_at
      t.index [:eventable_type, :eventable_id]
    end
  end
end 