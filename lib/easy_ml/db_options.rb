module EasyML
  module DbOptions
    def self.parse(options, klass)
      klass = klass.class unless klass.is_a?(Class)
      options.deep_symbolize_keys!
      db_options = options.slice(*(options.keys & klass.column_names.map(&:to_sym)))

      klass.reflect_on_all_associations.each do |association|
        association_name = association.name
        next unless options.key?(association_name)

        # options[association_name].is_a?(association.klass)
        #                         options[association_name]
        #                       else
        #                         association.klass.find_or_initialize_by(options[association_name])
        #                       end
        #   send("#{association_name}=", associated_object)
        # elsif options.key?(association.foreign_key.to_sym)
        #   associated_object = association.klass.find_by(id: options[association.foreign_key.to_sym])
        #   send("#{association_name}=", associated_object)
        db_options[association_name] = options[association_name]
      end

      db_options
    end
  end
end
