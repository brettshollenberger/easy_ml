module EasyML
  class FileDatasource < Datasource
    attr_accessor :polars_args

    after_initialize :read_from_configuration
    before_save :store_in_configuration

    def polars_args=(args)
      args[:dtypes] = args[:dtypes].stringify_keys if args&.key?(:dtypes)
      @polars_args = args
    end

    def in_batches(&block)
      reader.in_batches(&block)
    end

    def files
      reader.files
    end

    def last_updated_at
      files.map { |file| File.mtime(file) }.max
    end

    def refresh; end
    def refresh!; end

    def data
      return @combined_df if @combined_df.present?

      combined_df = nil
      reader.in_batches do |df|
        combined_df = combined_df.nil? ? df : combined_df.vstack(df)
      end
      @combined_df = combined_df
    end

    private

    def reader
      @reader ||= EasyML::PolarsReader.new(
        root_dir: root_dir,
        polars_args: polars_args
      )
    end

    def store_in_configuration
      super(:polars_args)
    end

    def read_from_configuration
      super(:polars_args)
    end
  end
end
