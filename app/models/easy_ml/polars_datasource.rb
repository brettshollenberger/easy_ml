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
  class PolarsDatasource < Datasource
    self.inheritance_column = :datasource_type
    self.table_name = "easy_ml_datasources"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    attr_accessor :df

    validates :df, presence: true

    after_initialize :read_df_from_configuration
    after_find :read_df_from_configuration
    before_save :store_df_in_configuration

    def df_is_dataframe
      return if df.is_a?(Polars::DataFrame)

      errors.add(:df, "Must be an instance of Polars::DataFrame")
    end

    def in_batches(of: 10_000)
      total_rows = df.shape[0]
      (0...total_rows).step(of) do |start|
        end_index = [start + of, total_rows].min
        yield df.slice(start, end_index - start)
      end
    end

    def query(drop_cols: [], filter: nil, limit: nil, select: nil, unique: nil, sort: nil, descending: false)
      return if df.nil?

      df = self.df.clone
      df = df.filter(filter) if filter
      df = df.select(select) if select.present?
      df = df.unique if unique
      drop_cols &= df.columns
      df = df.drop(drop_cols) unless drop_cols.empty?
      df = df.sort(sort, reverse: descending) if sort
      df = df.limit(limit) if limit
      df
    end

    def files
      [] # No files, as this is in-memory
    end

    def needs_refresh?
      false
    end

    def refresh
      syncing do
        # No need to refresh for in-memory datasource
      end
    end

    def refresh!
      syncing do
        # No need to refresh for in-memory datasource
      end
    end

    def is_syncing
      false
    end

    def data
      df
    end

    def last_updated_at
      updated_at
    end

    private

    def store_df_in_configuration
      return unless df

      self.configuration = (configuration || {}).merge(
        "df" => JSON.parse(df.write_json),
      )
    end

    def read_df_from_configuration
      return unless configuration&.key?("df")

      df_data = configuration["df"]
      columns = df_data["columns"].map do |col|
        dtype = case col["datatype"]
          when Hash
            if col["datatype"]["Datetime"]
              Polars::Datetime.new(col["datatype"]["Datetime"][0].downcase.to_sym).class
            else
              Polars::Utf8
            end
          else
            Polars.const_get(col["datatype"])
          end
        Polars::Series.new(col["name"], col["values"], dtype: dtype)
      end

      @df = Polars::DataFrame.new(columns)
    end
  end
end
