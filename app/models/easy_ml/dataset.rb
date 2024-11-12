# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  description     :string
#  dataset_type    :string
#  status          :string
#  version         :string
#  datasource_id   :bigint
#  root_dir        :string
#  configuration   :json
#  num_rows        :bigint
#  workflow_status :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
require_relative "concerns/statuses"
module EasyML
  class Dataset < ActiveRecord::Base
    include EasyML::Concerns::Statuses

    enum workflow_status: {
      analyzing: "analyzing",
      ready: "ready",
      failed: "failed",
      locked: "locked"
    }

    self.filter_attributes += [:configuration]

    include GlueGun::Model
    service :dataset, EasyML::Data::Dataset

    validates :name, presence: true
    belongs_to :datasource,
               foreign_key: :datasource_id,
               class_name: "EasyML::Datasource"

    has_many :models, class_name: "EasyML::Model"
    has_many :columns, class_name: "EasyML::Column", dependent: :destroy
    accepts_nested_attributes_for :columns, allow_destroy: true, update_only: true

    has_many :dataset_transforms, -> { ordered }, dependent: :destroy

    before_destroy :cleanup!

    # Maybe copy attrs over from training to prod when marking is_live, so we keep 1 for training and one for live?
    #
    # def fit
    #   raise "Cannot train live dataset!" if is_live
    # end

    def self.constants
      {
        column_types: EasyML::Data::PolarsColumn::TYPE_MAP.keys.map do |type|
          { value: type.to_s, label: type.to_s.titleize }
        end,
        preprocessing_strategies: EasyML::Data::Preprocessor.constants[:preprocessing_strategies]
      }
    end

    def cleanup!
      FileUtils.rm_rf(File.join(root_dir, "data"))
    end

    def learn_statistics
      datasource&.learn_statistics
      sync_columns
    end

    def statistics
      datasource&.statistics
    end

    def schema
      datasource&.schema
    end

    def num_rows
      datasource&.num_rows
    end

    def refresh_async
      EasyML::RefreshDatasetWorker.perform_async(id)
    end

    def refresh
      return false if locked?

      update(workflow_status: "analyzing")
      dataset_service.refresh
      sync_columns
      update(workflow_status: "ready")
    rescue StandardError => e
      update(workflow_status: "failed")
      raise e
    end

    def sync_columns
      return unless schema.present?

      EasyML::Column.transaction do
        col_names = schema.keys
        existing_columns = columns.where(name: col_names)
        new_columns = col_names - existing_columns.map(&:name)
        cols_to_insert = new_columns.map do |col_name|
          EasyML::Column.new(
            name: col_name,
            dataset_id: id
          )
        end
        EasyML::Column.import(cols_to_insert)
        columns_to_update = columns.where(name: col_names)
        stats = statistics
        cached_sample = data(limit: 100, all_columns: true)
        polars_types = cached_sample.columns.zip(cached_sample.dtypes).to_h
        columns_to_update.each do |column|
          column.assign_attributes(
            statistics: stats[column.name],
            datatype: schema[column.name],
            polars_datatype: polars_types[column.name],
            sample_values: data(unique: true, limit: 5, select: column.name,
                                all_columns: true)[column.name].to_a.uniq[0...5]
          )
        end
        EasyML::Column.import(columns_to_update.to_a,
                              { on_duplicate_key_update: { columns: %i[statistics datatype polars_datatype
                                                                       sample_values] } })
      end
    end

    def apply_transforms!
      dataset_transforms.pending.each(&:apply!)
    end
  end
end
