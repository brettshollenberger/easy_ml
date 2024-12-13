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
    MAX_LINE_LENGTH = 65
    self.table_name = "easy_ml_events"

    STATUSES = %w[started success failed].freeze

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
    scope :failed, -> { where(status: "failed") }

    def self.create_event(model, status, error = nil)
      EasyML::Event.create!(
        name: model.class.name.demodulize,
        status: status,
        eventable: model,
        stacktrace: format_stacktrace(error),
      )
    end

    def self.handle_error(model, error)
      if error.is_a?(String)
        begin
          raise error
        rescue StandardError => e
          error = e
        end
      end
      create_event(model, "failed", error)
      Rails.logger.error("#{self.class.name} failed: #{error.message}")
    end

    def self.format_stacktrace(error)
      return nil if error.nil?

      topline = error.inspect

      stacktrace = error.backtrace.select do |loc|
        loc.match?(/easy_ml/)
      end

      %(#{topline}

        #{stacktrace.join("\n")}
      ).split("\n").map do |l|
        l.gsub(/\s{2,}/, " ").strip
      end.flat_map { |line| wrap_text(line, MAX_LINE_LENGTH) }.join("\n")
    end

    def self.wrap_text(text, max_length)
      text.strip.scan(/.{1,#{max_length}}/)
    end
  end
end
