# == Schema Information
#
# Table name: easy_ml_feature_histories
#
#  id                 :bigint           not null, primary key
#  feature_id         :integer          not null
#  dataset_id         :integer          not null
#  name               :string
#  version            :integer
#  feature_class      :string           not null
#  feature_position   :integer
#  batch_size         :integer
#  needs_fit          :boolean
#  sha                :string
#  primary_key        :string
#  applied_at         :datetime
#  fit_at             :datetime
#  refresh_every      :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#  workflow_status    :string
#
module EasyML
  class FeatureHistory < ActiveRecord::Base
    self.table_name = "easy_ml_feature_histories"
    include Historiographer::History

    after_find :download_remote_files
    scope :ordered, -> { order(feature_position: :asc) }
    scope :ready_to_apply, -> { where.not(id: needs_fit.map(&:id)) }
    scope :has_changes, lambda {
      none
    }
    scope :never_applied, -> { where(applied_at: nil) }
    scope :never_fit, -> do
            fittable = where(fit_at: nil)
            fittable = fittable.select { |f| f.adapter.respond_to?(:fit) }
            where(id: fittable.map(&:id))
          end
    scope :needs_fit, -> { has_changes.or(never_applied).or(never_fit) }
    scope :ready_to_apply, -> { where.not(id: needs_fit.map(&:id)) }

    def wipe
      false
    end

    def download_remote_files
      feature_store&.download
    end
  end
end
