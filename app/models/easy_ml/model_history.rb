# == Schema Information
#
# Table name: easy_ml_model_histories
#
#  id                 :bigint           not null, primary key
#  model_id           :integer          not null
#  name               :string           not null
#  model_type         :string
#  status             :string
#  dataset_id         :integer
#  model_file_id      :integer
#  configuration      :json
#  version            :string           not null
#  root_dir           :string
#  file               :json
#  sha                :string
#  last_trained_at    :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class ModelHistory < ActiveRecord::Base
    self.table_name = "easy_ml_model_histories"
    include Historiographer::History

    scope :latest_snapshots, lambda {
      where.not(snapshot_id: nil)
           .select("DISTINCT ON (model_id) *")
           .order("model_id, id DESC")
    }

    def status
      @status ||= if is_latest_snapshot?
                    :inference
                  else
                    :retired
                  end
    end

    def is_latest_snapshot?
      original_class.find_by(name: name).latest_snapshot.id == id
    end

    def fit
      raise "Cannot train inference model"
    end
  end
end
