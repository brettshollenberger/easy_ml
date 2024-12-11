module EasyML
  module Concerns
    module Lockable
      extend ActiveSupport::Concern

      LOCK_TIMEOUT = 1.hour

      included do
        raise "Model must have locked_at column" unless column_names.include?("locked_at")

        scope :locked, lambda {
          where("locked_at IS NOT NULL AND locked_at > ?", LOCK_TIMEOUT.ago)
        }

        scope :unlocked, lambda {
          where("locked_at IS NULL OR locked_at <= ?", LOCK_TIMEOUT.ago)
        }
      end

      def locked?
        return false if locked_at.nil?
        return false if locked_at <= LOCK_TIMEOUT.ago

        true
      end

      def lock_job!
        return true if locked?

        transaction do
          # Lock with optimistic locking to prevent race conditions
          reload
          return false if locked?
          update!(locked_at: Time.current)
        end

        true
      rescue ActiveRecord::StaleObjectError
        false
      end

      def unlock_job!
        update!(locked_at: nil)
        true
      end

      def with_lock
        return false unless lock_job!

        begin
          yield
        ensure
          unlock_job!
        end
      end
    end
  end
end
