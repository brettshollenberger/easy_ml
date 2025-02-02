class AddDefaultToIsTarget < ActiveRecord::Migration[7.2]
  def change
    change_column_default(:easy_ml_columns, :is_target, false)
    change_column_default(:easy_ml_column_histories, :is_target, false)
  end
end
