# == Schema Information
#
# Table name: easy_ml_pca_models
#
#  id         :bigint           not null, primary key
#  model      :binary           not null
#  fit_at     :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
module EasyML
  class PCAModel < ActiveRecord::Base
    def model
      model = read_attribute(:model)
      return nil if model.nil?

      Marshal.load(model)
    end

    def model=(model)
      write_attribute(:model, Marshal.dump(model.dup))
    end
  end
end
