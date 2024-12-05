# == Schema Information
#
# Table name: easy_ml_transform_histories
#
#  id                 :bigint           not null, primary key
#  transform_id       :integer          not null
#  dataset_id         :integer          not null
#  name               :string
#  transform_class    :string           not null
#  transform_method   :string           not null
#  transform_position :integer
#  applied_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class TransformHistory < ActiveRecord::Base
    self.table_name = "easy_ml_transform_histories"
    include Historiographer::History
  end
end
