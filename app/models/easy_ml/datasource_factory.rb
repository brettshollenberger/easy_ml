# require_relative "merged_datasource"

module EasyML
  class DatasourceFactory
    include GlueGun::DSL

    dependency :datasource do |dependency|
      dependency.option :s3 do |option|
        option.default
        option.set_class EasyML::Data::Datasource::S3Datasource
        option.bind_attribute :root_dir do |value|
          Pathname.new(value).append("files")
        end
        option.bind_attribute :polars_args, default: {}
        option.bind_attribute :s3_bucket, required: true
        option.bind_attribute :s3_prefix
        option.bind_attribute :s3_access_key_id, required: true
        option.bind_attribute :s3_secret_access_key, required: true
      end

      dependency.option :file do |option|
        option.set_class EasyML::Data::Datasource::FileDatasource
        option.bind_attribute :root_dir do |value|
          Pathname.new(value).append("files/raw")
        end
        option.bind_attribute :polars_args
      end

      dependency.option :polars do |option|
        option.set_class EasyML::Data::Datasource::PolarsDatasource
        option.bind_attribute :df
      end

      dependency.option :merged do |option|
        option.set_class EasyML::Data::Datasource::MergedDatasource
        option.bind_attribute :root_dir
      end

      # Passing in datasource: Polars::DataFrame will wrap properly
      # So will passing in datasource /path/to/dir
      dependency.when do |dep|
        case dep
        when Polars::DataFrame
          { option: :polars, as: :df }
        when String, Pathname
          { option: :file, as: :root_dir }
        end
      end
    end
  end
end

# Do this here otherwise we'll end up with a circular dependency
# class EasyML::Data::Datasource::MergedDatasource
#   dependency :datasources, DatasourceFactory
# end
