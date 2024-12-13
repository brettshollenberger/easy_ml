module EasyML
  class DeployWorker < ApplicationWorker
    def perform(id)
      deploy = EasyML::Deploy.find(id)
      raise "Model already being deployed" unless deploy.unlocked?

      # Use Suo instead
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
