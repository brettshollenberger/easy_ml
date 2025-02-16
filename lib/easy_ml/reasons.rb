module EasyML
  class Reasons
    def initialize(context)
      @context = context
      @reasons = {}
    end

    class << self
      def add_reason(name, check)
        @reasons ||= {}
        key = name.to_s.downcase.gsub(/\s/, "_").to_sym
        @reasons[key] = { name: name, check: check }
      end

      def reasons
        @reasons ||= {}
      end
    end

    def inspect
      "#<#{self.class.name.split("::").last} checks=[#{self.class.reasons.map { |k, v| "#{v[:name]}" }.join(", ")}]>"
    end

    def none?(except: [])
      check(except: except).none?
    end

    def check(except: [])
      self.class.reasons.except(*except).select do |_, config|
        @context.instance_exec(&config[:check])
      end.map do |_, config|
        config[:name]
      end
    end

    def explain
      reasons = check
      reasons.any? ? reasons.join(", ") : :none
    end
  end
end
