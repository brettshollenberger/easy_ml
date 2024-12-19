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
require "jsonapi/serializer"

module EasyML
  class DatasourceSerializer
    include JSONAPI::Serializer

    set_type :datasource # Optional type for JSON:API

    attributes :id, :name, :datasource_type, :s3_bucket, :s3_prefix, :s3_region, :schema, :columns, :available_files

    attribute :last_synced_at do |datasource|
      if datasource.is_syncing
        "Syncing..."
      else
        datasource.last_updated_at ? datasource.last_updated_at.in_time_zone(EasyML::Configuration.timezone) : "Not Synced"
      end
    end

    attribute :created_at do |datasource|
      datasource.created_at.in_time_zone(EasyML::Configuration.timezone).iso8601
    end

    attribute :updated_at do |datasource|
      datasource.updated_at.in_time_zone(EasyML::Configuration.timezone).iso8601
    end

    attribute :is_synced do |datasource|
      datasource.last_updated_at.present?
    end

    attribute :is_syncing do |datasource|
      datasource.is_syncing
    end

    attribute :sync_failed do |datasource|
      if datasource.is_syncing
        nil
      else
        datasource.events.order(id: :desc).limit(1)&.last&.status == "failed"
      end
    end

    attribute :stacktrace do |datasource|
      if datasource.is_syncing
        nil
      else
        last_event = datasource.events.order(id: :desc).limit(1).last
        last_event&.stacktrace if last_event&.status == "failed"
      end
    end
  end
end
