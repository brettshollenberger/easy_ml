module EasyML
  class Datasource < ActiveRecord::Base
    self.filter_attributes += [:configuration]
    include GlueGun::Model

    service :polars, EasyML::Data::Datasource::PolarsDatasource
    service :s3, EasyML::Data::Datasource::S3Datasource
    service :file, EasyML::Data::Datasource::FileDatasource
  end
end
