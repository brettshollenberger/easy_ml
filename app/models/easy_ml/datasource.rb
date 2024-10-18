require_relative "datasource_factory"

module EasyML
  class Datasource < ActiveRecord::Base
    attr_accessor :datasource

    def initialize(attributes = {})
      @datasource = DatasourceFactory.new(
        datasource: attributes
      ).datasource.values.first
      super(attributes.slice(*self.class.column_names.map(&:to_sym)))
    end

    delegate :in_batches, :files, :last_updated_at, :refresh!, :data, to: :datasource
  end
end
