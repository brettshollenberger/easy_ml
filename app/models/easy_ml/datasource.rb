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
    self.filter_attributes += [:configuration]
    self.inheritance_column = :datasource_type

    TYPE_MAP = {
      polars: "PolarsDatasource",
      s3: "S3Datasource",
      file: "FileDatasource"
    }.freeze

    validates :name, presence: true
    validates :datasource_type, presence: true
    validates :datasource_type, inclusion: { in: %w[PolarsDatasource S3Datasource FileDatasource] }

    before_validation :normalize_datasource_type

    def self.find_sti_class(type_name)
      # If it's already a valid STI type, use it directly
      return "EasyML::#{type_name}".constantize if type_name.in?(TYPE_MAP.values)

      # Convert to symbol for lookup
      type_key = type_name.to_s.underscore.to_sym

      # Use the mapped class name if it exists, otherwise use the original
      normalized_type = TYPE_MAP[type_key] || type_name

      "EasyML::#{normalized_type}".constantize
    end

    def self.sti_name
      name.demodulize
    end

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

    def datasource_type=(value)
      @datasource_type = value
      normalize_datasource_type
      super(@datasource_type)
    end

    private

    def normalize_datasource_type
      return if @datasource_type.nil?
      return if @datasource_type.in?(TYPE_MAP.values) # Already normalized

      # Convert symbol to string if needed
      type_key = @datasource_type.to_sym if @datasource_type.respond_to?(:to_sym)

      # Map the friendly type to the STI type if it exists in our mapping
      @datasource_type = TYPE_MAP[type_key] if TYPE_MAP.key?(type_key)
    end

    def store_in_configuration(*attrs)
      attrs.each do |attr|
        value = instance_variable_get("@#{attr}")
        next if value.nil?

        self.configuration = (configuration || {}).merge(attr.to_s => value)
      end
    end

    def read_from_configuration(*attrs)
      return unless configuration

      attrs.each do |attr|
        next unless configuration.key?(attr.to_s)

        instance_variable_set("@#{attr}", configuration[attr.to_s])
      end
    end
  end
end
