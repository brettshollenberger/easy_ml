module EasyML
  class Dataset < ActiveRecord::Base
    before_save :serialize
    after_find :deserialize

    validates :name, presence: true
    belongs_to :datasource,
               foreign_key: :datasource_id,
               class_name: "EasyML::Datasource"

    def initialize(options = {})
      super(EasyML::DbOptions.parse(options, self))
      build_dataset_service(options)
    end

    attr_accessor :dataset_service

    private

    def build_dataset_service(options)
      options.deep_symbolize_keys!
      service_klass = EasyML::Data::Dataset

      allowed_attr_names = service_klass.dependency_definitions.keys.concat(
        service_klass.attribute_definitions.keys
      )

      allowed_attrs = options.slice(*allowed_attr_names)
      @dataset_service = service_klass.new(allowed_attrs)
      define_dataset_service_delegators(allowed_attr_names)
    end

    def define_dataset_service_delegators(attr_names)
      allowed_names(attr_names).each do |attr_name|
        define_singleton_method(attr_name) do
          dataset_service.send(attr_name)
        end
      end
    end

    def allowed_names(names)
      assoc_names = self.class.reflect_on_all_associations.map(&:name)
      [names.map(&:to_sym) - assoc_names.map(&:to_sym)].flatten
    end

    def serialize
      attrs = dataset_service.attributes
      deps = allowed_names(dataset_service.dependency_definitions.keys).inject({}) do |hash, dep|
        hash.tap do
          this_dep = dataset_service.send(dep)
          next unless this_dep.present?

          opts = dataset_service.dependency_definitions[dep].option_configs
          selected_option = opts.detect do |_k, v|
            this_dep.class == v.class_name
          end.first
          hash[dep] = {
            selected_option => dataset_service.send(dep).attributes
          }
        end
      end
      json = attrs.merge(deps).deep_symbolize_keys.deep_compact
      write_attribute(:configuration, json.to_json)
    end

    def deserialize
      options = JSON.parse(read_attribute(:configuration))
      options.deep_symbolize_keys!

      build_dataset_service(options)
    end
  end
end
