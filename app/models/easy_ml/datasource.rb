# == Schema Information
#
# Table name: easy_ml_datasources
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  datasource_type :string
#  root_dir        :string
#  configuration   :json
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
module EasyML
  class Datasource < ActiveRecord::Base
    self.filter_attributes += [:configuration]
    include GlueGun::Model

    service :polars, EasyML::Data::Datasource::PolarsDatasource
    service :s3, EasyML::Data::Datasource::S3Datasource
    service :file, EasyML::Data::Datasource::FileDatasource

    validates :name, presence: true
    validates :datasource_type, presence: true
    validates :datasource_type, inclusion: { in: %w[polars s3 file] }
  end
end
