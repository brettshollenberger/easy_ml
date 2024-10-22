module EasyML
  class Datasource < ActiveRecord::Base
    before_save :serialize
    after_find :deserialize

    def initialize(options = {})
      options.deep_symbolize_keys!
      db_options = options.slice(*(options.keys & self.class.column_names.map(&:to_sym)))
      super(db_options)
      build_datasource_service(options)
    end

    # This is the main issue to figure out... which methods to delegate & how to figure this out programmatically
    delegate :data, :in_batches, :df, :refresh!, :refresh, :last_updated_at,
             to: :datasource_service

    attr_accessor :datasource_service

    private

    def build_datasource_service(options)
      options.deep_symbolize_keys!
      if options.key?(:df)
        service_klass = EasyML::Data::Datasource::PolarsDatasource
      elsif options.key?(:s3)
        root_options = options.except(:s3)
        options = options[:s3].merge!(root_options)
        service_klass = EasyML::Data::Datasource::S3Datasource
      elsif options.key?(:root_dir)
        service_klass = EasyML::Data::Datasource::FileDatasource
      end

      allowed_attrs = options.slice(*service_klass.new.attributes.keys.map(&:to_sym))
      @datasource_service = service_klass.new(allowed_attrs)
    end

    def serialize
      write_attribute(:configuration, datasource_service.serialize.to_json)
    end

    def deserialize
      options = JSON.parse(read_attribute(:configuration))
      options.deep_symbolize_keys!

      deserialize_polars(options) if options.key?(:df)

      build_datasource_service(options)
    end

    def deserialize_polars(options)
      df = options[:df]
      columns = df[:columns].map do |col|
        # Determine the correct data type
        dtype = case col[:datatype]
                when Hash
                  if col[:datatype][:Datetime]
                    Polars::Datetime.new(col[:datatype][:Datetime][0].downcase.to_sym).class
                  else
                    Polars::Utf8
                  end
                else
                  Polars.const_get(col[:datatype])
                end
        # Create a Series for each column
        Polars::Series.new(col[:name], col[:values], dtype: dtype)
      end

      # Create the DataFrame
      options[:df] = Polars::DataFrame.new(columns)
    end
  end
end
