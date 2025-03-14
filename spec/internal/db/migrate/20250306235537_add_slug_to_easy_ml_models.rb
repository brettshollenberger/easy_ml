class AddSlugToEasyMLModels < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_models, :slug, :string
    add_index :easy_ml_models, :slug, unique: true

    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE easy_ml_models
          SET slug = LOWER(REPLACE(name, ' ', '_'))
        SQL
      end
    end

    change_column_null :easy_ml_models, :slug, false

    add_column :easy_ml_model_histories, :slug, :string
    add_index :easy_ml_model_histories, :slug
  end
end
