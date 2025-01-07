module EasyML
  module Initializers
    module Inflections
      def self.inflect
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym "EasyML"
          inflect.acronym "ML"
          inflect.acronym "STI"
          inflect.acronym "XGBoost"
          inflect.acronym "GBLinear"
          inflect.acronym "GBTree"
          inflect.acronym "EST"
          inflect.acronym "UTC"
          inflect.acronym "HTML"
        end
      end
    end
  end
end
