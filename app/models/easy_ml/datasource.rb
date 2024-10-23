module EasyML
  class Datasource < ActiveRecord::Base
    include GlueGun::Model

    service :polars, EasyML::Data::Datasource::PolarsDatasource
    service :s3, EasyML::Data::Datasource::S3Datasource
    service :file, EasyML::Data::Datasource::FileDatasource
  end
end
