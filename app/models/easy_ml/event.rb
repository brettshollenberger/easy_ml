# == Schema Information
#
# Table name: easy_ml_events
#
#  id             :bigint           not null, primary key
#  name           :string           not null
#  status         :string           not null
#  eventable_type :string
#  eventable_id   :bigint
#  stacktrace     :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
module EasyML
  class Event < ActiveRecord::Base
    self.table_name = "easy_ml_events"

    STATUSES = %w[started success error].freeze

    belongs_to :eventable, polymorphic: true, optional: true

    validates :name, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }

    # Helper method to extract worker name from class
    def self.worker_name(worker_class)
      worker_class.to_s.demodulize
    end

    # Scopes to help query events
    scope :for_worker, ->(worker_class) { where(name: worker_name(worker_class)) }
    scope :started, -> { where(status: "started") }
    scope :succeeded, -> { where(status: "success") }
    scope :failed, -> { where(status: "error") }
  end
end
