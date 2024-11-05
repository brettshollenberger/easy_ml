require "jsonapi/serializer"

module EasyML
  class DatasourceSerializer
    include JSONAPI::Serializer

    set_type :datasource # Optional type for JSON:API

    attributes :id, :name, :datasource_type, :s3_bucket, :s3_prefix, :s3_region

    attribute :last_synced_at do |object|
      if object.is_syncing
        "Syncing..."
      else
        object.last_updated_at ? object.last_updated_at.in_time_zone(EasyML::Configuration.timezone) : "Not Synced"
      end
    end

    attribute :created_at do |object|
      object.created_at.in_time_zone(EasyML::Configuration.timezone).iso8601
    end

    attribute :updated_at do |object|
      object.updated_at.in_time_zone(EasyML::Configuration.timezone).iso8601
    end

    attribute :is_syncing do |object|
      object.is_syncing
    end

    attribute :sync_error do |object|
      object.events.order(id: :desc).limit(1)&.last&.status == "error"
    end

    attribute :stacktrace do |object|
      if object.is_syncing
        nil
      else
        last_event = object.events.order(id: :desc).limit(1).last
        last_event&.stacktrace if last_event&.status == "error"
      end
    end
  end
end
