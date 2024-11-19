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
    include EasyML::Concerns::Configurable

    SPLITTER_TYPES = [
      {
        value: "date",
        label: "Date Splitter",
        description: "Split dataset based on date ranges for training, validation, and testing",
      },
    ].freeze

    self.inheritance_column = :splitter_type

    belongs_to :dataset, class_name: "EasyML::Dataset"
    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy

    validates :splitter_type, presence: true
    validates :splitter_type, inclusion: { in: ["EasyML::DateSplitter"] }

    # Configuration attributes for DateSplitter
    add_configuration_attributes :today, :date_col, :months_test, :months_valid

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
