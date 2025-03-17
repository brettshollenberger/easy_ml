require_relative "./column_serializer"

# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id                      :bigint           not null, primary key
#  name                    :string           not null
#  description             :string
#  dataset_type            :string
#  status                  :string
#  version                 :string
#  datasource_id           :bigint
#  root_dir                :string
#  configuration           :json
#  num_rows                :bigint
#  workflow_status         :string
#  statistics              :json
#  preprocessor_statistics :json
#  schema                  :json
#  refreshed_at            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
module EasyML
  class DatasetSerializer
    class SmallSerializer
      include JSONAPI::Serializer

      attributes :id, :name, :description, :target, :num_rows, :status,
                 :datasource_id, :preprocessing_steps, :workflow_status, :statistics

      attribute :columns do |dataset|
        dataset.columns.order(:id).map do |column|
          ColumnSerializer::SmallSerializer.new(column).serializable_hash.dig(:data, :attributes)
        end
      end
      attribute :stacktrace do |object|
        if !object.failed? || object.events.empty?
          nil
        else
          last_event = object.events.where(status: :failed).order(id: :desc).limit(1).last
          last_event&.stacktrace
        end
      end
    end

    include JSONAPI::Serializer

    attributes :id, :name, :description, :target, :num_rows, :status,
               :datasource_id, :preprocessing_steps, :workflow_status, :statistics

    attribute :date_column do |dataset|
      dataset.date_column&.name
    end

    attribute :splitter do |dataset|
      dataset.splitter
    end

    attribute :columns do |dataset|
      col_order = dataset.col_order
      dataset.columns.sort_by { |c| col_order.index(c.name) || Float::INFINITY }.map do |column|
        ColumnSerializer.new(column).serializable_hash.dig(:data, :attributes)
      end
    end

    attribute :sample_data do |dataset|
      if dataset.workflow_status.to_sym == :analyzing
        nil
      else
        dataset.data(limit: 10, all_columns: true, refresh: false)&.to_hashes || dataset.raw.data(limit: 10, all_columns: true)&.to_hashes
      end
    end

    attribute :updated_at do |dataset|
      dataset.datasource&.last_updated_at
    end

    attribute :features do |dataset|
      dataset.features.ordered.map do |feature|
        FeatureSerializer.new(feature).serializable_hash.dig(:data, :attributes)
      end
    end

    attribute :needs_refresh do |dataset|
      dataset.needs_refresh?(except: [:datasource_needs_refresh])
    end

    attribute :stacktrace do |object|
      if !object.failed? || object.events.empty?
        nil
      else
        last_event = object.events.where(status: :failed).order(id: :desc).limit(1).last
        last_event&.stacktrace
      end
    end
  end
end
