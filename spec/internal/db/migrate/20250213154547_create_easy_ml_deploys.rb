class CreateEasyMLDeploys < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_deploys)
      create_table :easy_ml_deploys do |t|
        t.bigint :model_id
        t.bigint :model_history_id
        t.bigint :retraining_run_id
        t.bigint :model_file_id
        t.string :status, null: false
        t.string :trigger, default: 'manual'
        t.text :stacktrace
        t.string :snapshot_id
        t.timestamps

        t.index :created_at
        t.index :model_id
        t.index :model_history_id
        t.index :snapshot_id
        t.index :model_file_id
        t.index :retraining_run_id
        t.index :status
        t.index :trigger
      end
    end
  end
end