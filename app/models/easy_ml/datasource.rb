module EasyML
  class Datasource < ActiveRecord::Base
    include GlueGun::Model

    service do |options|
      if options.key?(:df)
        EasyML::Data::Datasource::PolarsDatasource
      elsif options.key?(:s3_bucket)
        EasyML::Data::Datasource::S3Datasource
      elsif options.key?(:root_dir)
        EasyML::Data::Datasource::FileDatasource
      end
    end

    delegate :data, :in_batches, :df, :refresh!, :refresh, :last_updated_at,
             to: :datasource_service
  end
end
