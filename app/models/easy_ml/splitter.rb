module EasyML
  class Splitter
    def self.build(options)
      case options[:type].to_s
      when "date"
        DateSplitter.new(
          today: options[:today],
          date_col: options[:date_col],
          months_test: options[:months_test],
          months_valid: options[:months_valid]
        )
      else
        raise ArgumentError, "Unknown splitter type: #{options[:type]}"
      end
    end
  end
end
