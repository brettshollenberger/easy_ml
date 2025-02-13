class AddUniqueConstraintToEasyMLModelNames < ActiveRecord::Migration[7.2]
  def change
    if index_exists?(:easy_ml_models, :name)
      remove_index :easy_ml_models, :name
    end
    add_index :easy_ml_models, :name, unique: true
  end
end
