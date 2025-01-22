module EasyML
  class CleanJob < ApplicationJob
    @queue = :easy_ml

    def perform
      EasyML::Cleaner.clean
    end
  end
end
