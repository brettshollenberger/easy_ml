module EasyML
  class DeployWorker < ApplicationWorker
    include Sidekiq::Worker

    sidekiq_options(
      queue: :easy_ml,
      retry: false,
      lock: :until_executed,
      on_conflict: :log,
      lock_args_method: ->(args) { args.first },
    )

    def perform(id)
      deploy = EasyML::Deploy.find(id)
      raise "Model already being deployed" unless deploy.unlocked?

      deploy.lock_job!
      deploy.update(status: "running")
      create_event(deploy, "started")

      begin
        deploy.deploy
        create_event(deploy, "success")
      rescue StandardError => e
        handle_error(deploy, e)
      ensure
        deploy.unlock_job!
      end
    end
  end
end
