# == Schema Information
#
# Table name: easy_ml_splitters
#
#  id            :bigint           not null, primary key
#  splitter_type :string           not null
#  configuration :json
#  dataset_id    :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
module EasyML
  class Splitter < ActiveRecord::Base
    self.table_name = "easy_ml_splitters"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Concerns::Configurable

    SPLITTER_OPTIONS = {
      "date" => "EasyML::Splitters::DateSplitter",
      "random" => "EasyML::Splitters::RandomSplitter",
      "predefined" => "EasyML::Splitters::PredefinedSplitter",
    }
    SPLITTER_TYPES = [
      {
        value: "date",
        label: "Date Splitter",
        description: "Split dataset based on date ranges for training, validation, and testing",
      },
      {
        value: "random",
        label: "Random Splitter",
        description: "Randomly split dataset into training, validation, and testing sets with configurable ratios",
      },
      {
        value: "predefined",
        label: "Predefined Splitter",
        description: "Split dataset using predefined file assignments for training, validation, and testing sets",
      },
    ].freeze

    belongs_to :dataset, class_name: "EasyML::Dataset"
    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy

    validates :splitter_type, presence: true
    validates :splitter_type, inclusion: { in: SPLITTER_OPTIONS.keys }

    SPLITTER_NAMES = SPLITTER_OPTIONS.keys.freeze
    SPLITTER_CONSTANTS = SPLITTER_OPTIONS.values.map(&:constantize)
    SPLITTER_CONSTANTS.flat_map(&:configuration_attributes).each do |attribute|
      add_configuration_attributes attribute
    end

    def self.constants
      {
        SPLITTER_TYPES: SPLITTER_TYPES,
      }
    end

    def split(df, &block)
      adapter.split(df, &block)
    end

    def splits
      adapter.splits
    end

    private

    def adapter
      @adapter ||= begin
          adapter_class = SPLITTER_OPTIONS[splitter_type]
          raise "Don't know how to use splitter #{splitter_type}!" unless adapter_class.present?

          attrs = adapter_class.constantize.configuration_attributes
          adapter_class.constantize.new(self).tap do |adapter|
            attrs.each do |attr|
              adapter.send("#{attr}=", send(attr))
            end
          end
        end
    end
  end
end
