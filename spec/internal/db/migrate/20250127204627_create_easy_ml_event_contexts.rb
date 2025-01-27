class CreateEasyMLEventContexts < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_event_contexts do |t|
      t.references :event, null: false, foreign_key: { to_table: :easy_ml_events }
      t.jsonb :context, null: false, default: {}
      t.string :format
      t.timestamps
    end

    add_index :easy_ml_event_contexts, :context, using: :gin
  end
end
