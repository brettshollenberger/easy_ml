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
  class FileDatasource < Datasource
    attr_accessor :polars_args

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

    def needs_refresh?
      false
    end

    def refresh
      syncing do
        # syncing ensures we call before & after, but no actual work for file datasource
      end
    end

    def refresh!
      syncing do
        # syncing ensures we call before & after, but no actual work for file datasource
      end
    end

    def is_syncing
      false
    end

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
  end
end
