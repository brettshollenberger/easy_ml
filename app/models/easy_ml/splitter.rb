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
    self.inheritance_column = :splitter_type
    self.table_name = "easy_ml_splitters"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Concerns::Configurable

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
    ].freeze

    belongs_to :dataset, class_name: "EasyML::Dataset"
    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy

    validates :splitter_type, presence: true
    validates :splitter_type, inclusion: { in: ["EasyML::DateSplitter", "EasyML::RandomSplitter"] }

    def self.constants
      {
        SPLITTER_TYPES: SPLITTER_TYPES,
      }
    end

    def split
      raise NotImplementedError, "#{self.class} must implement #split"
    end
  end
end
