module EasyML
  module DatasourceOptions
    def self.constants
      EasyML::Datasource.constants.merge!(
        s3: EasyML::S3Datasource.constants
      )
    end
  end
end
