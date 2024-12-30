class CreateEasyMLSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_settings do |t|
      t.json :configuration

      t.timestamps
    end
  end
end 