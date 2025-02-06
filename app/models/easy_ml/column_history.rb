# == Schema Information
#
# Table name: easy_ml_column_histories
#
#  id                       :bigint           not null, primary key
#  column_id                :integer          not null
#  dataset_id               :integer          not null
#  name                     :string           not null
#  description              :string
#  datatype                 :string
#  polars_datatype          :string
#  is_target                :boolean          default(FALSE)
#  hidden                   :boolean          default(FALSE)
#  drop_if_null             :boolean          default(FALSE)
#  preprocessing_steps      :json
#  sample_values            :json
#  statistics               :json
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  history_started_at       :datetime         not null
#  history_ended_at         :datetime
#  history_user_id          :integer
#  snapshot_id              :string
#  is_date_column           :boolean          default(FALSE)
#  computed_by              :string
#  is_computed              :boolean          default(FALSE)
#  feature_id               :bigint
#  learned_at               :datetime
#  is_learning              :boolean          default(FALSE)
#  last_datasource_sha      :string
#  last_feature_sha         :string
#  configuration_changed_at :datetime
#
module EasyML
  class ColumnHistory < ActiveRecord::Base
    self.table_name = "easy_ml_column_histories"
    include Historiographer::History
    scope :required, -> { where(is_computed: false, hidden: false, is_target: false).where("preprocessing_steps IS NULL OR preprocessing_steps::text = '{}'::text") }
    scope :computed, -> { where(is_computed: true) }
    scope :raw, -> { where(is_computed: false) }
  end
end
