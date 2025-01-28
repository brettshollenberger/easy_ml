class DropPathFromEasyMLModelFiles < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:easy_ml_model_files, :path)
      remove_column :easy_ml_model_files, :path
    end

    if column_exists?(:easy_ml_model_file_histories, :path)
      remove_column :easy_ml_model_file_histories, :path
    end
  end
end