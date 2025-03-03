class CreateEasyMLPCAModels < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_pca_models)
      create_table :easy_ml_pca_models do |t|
        t.binary :model, null: false
        t.datetime :fit_at
        t.timestamps

        t.index :created_at
        t.index :fit_at
      end
    end
  end
end