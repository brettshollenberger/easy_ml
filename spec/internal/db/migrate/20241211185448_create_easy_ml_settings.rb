class CreateEasyMLSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_settings do |t|
      t.json :configuration

      t.timestamps
    end
  end
end 