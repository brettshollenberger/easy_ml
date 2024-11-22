# == Schema Information
#
# Table name: easy_ml_datasource_histories
#
#  id                 :bigint           not null, primary key
#  datasource_id      :integer          not null
#  name               :string           not null
#  datasource_type    :string
#  root_dir           :string
#  configuration      :json
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class S3DatasourceHistory < DatasourceHistory
    self.inheritance_column = :datasource_type
    self.table_name = "easy_ml_datasource_histories"
    include Historiographer::History
  end
end
