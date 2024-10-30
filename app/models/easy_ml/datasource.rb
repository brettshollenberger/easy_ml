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
    include Concerns::ConfigurableSti

    type_column :datasource_type
    register_types(
      polars: "PolarsDatasource",
      s3: "S3Datasource",
      file: "FileDatasource"
    )

    validates :name, presence: true
    validates :datasource_type, presence: true
    validates :datasource_type, inclusion: { in: type_map.values }

    # Common interface methods
    def in_batches(of: 10_000)
      raise NotImplementedError, "#{self.class} must implement #in_batches"
    end

    def files
      raise NotImplementedError, "#{self.class} must implement #files"
    end

    def last_updated_at
      raise NotImplementedError, "#{self.class} must implement #last_updated_at"
    end

    def refresh
      raise NotImplementedError, "#{self.class} must implement #refresh"
    end

    def refresh!
      raise NotImplementedError, "#{self.class} must implement #refresh!"
    end

    def data
      raise NotImplementedError, "#{self.class} must implement #data"
    end
  end
end
