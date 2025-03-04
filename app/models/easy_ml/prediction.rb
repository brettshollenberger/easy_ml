# == Schema Information
#
# Table name: easy_ml_predictions
#
#  id               :bigint           not null, primary key
#  model_id         :bigint           not null
#  model_history_id :bigint
#  prediction_type  :string
#  prediction_value :jsonb
#  raw_input        :jsonb
#  normalized_input :jsonb
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  metadata         :jsonb            not null
#
module EasyML
  class Prediction < ActiveRecord::Base
    self.table_name = "easy_ml_predictions"

    belongs_to :model, class_name: "EasyML::Model"
    belongs_to :model_history, class_name: "EasyML::ModelHistory", optional: true

    validates :model_id, presence: true
    validates :prediction_type, presence: true, inclusion: { in: %w[regression classification] }
    validates :prediction_value, presence: true
    validates :raw_input, presence: true
    validates :normalized_input, presence: true

    def prediction
      prediction_value["value"]
    end

    def probabilities
      metadata["probabilities"]
    end

    def regression?
      prediction_type == "regression"
    end

    def classification?
      prediction_type == "classification"
    end
  end
end
