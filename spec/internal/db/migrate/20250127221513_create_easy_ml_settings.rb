class CreateEasyMLSettings < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_settings)
      create_table :easy_ml_settings do |t|
        t.json :configuration

        t.timestamps
      end
    end
  end
end