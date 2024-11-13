# == Schema Information
#
# Table name: easy_ml_transforms
#
#  id               :bigint           not null, primary key
#  dataset_id       :bigint           not null
#  transform_class  :string           not null
#  transform_method :string           not null
#  parameters       :json
#  position         :integer
#  applied_at       :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
require "jsonapi/serializer"

module EasyML
  class TransformSerializer
    include JSONAPI::Serializer

    attributes :id, :transform_class, :transform_method

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

    attribute :is_synced do |object|
      object.last_updated_at.present?
    end

    attribute :is_syncing do |object|
      object.is_syncing
    end

    attribute :sync_error do |object|
      if object.is_syncing
        nil
      else
        object.events.order(id: :desc).limit(1)&.last&.status == "error"
      end
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
