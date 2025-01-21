module EasyML
  class CleanJob < ApplicationJob
    @queue = :easy_ml

    def self.perform
      EasyML::Cleaner.clean
    end
  end
end
