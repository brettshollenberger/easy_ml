module EasyML
  class DeployJob < ApplicationJob
    def perform(id)
      deploy = EasyML::Deploy.find(id)

      begin
        deploy.actually_deploy
      rescue StandardError => e
        handle_error(deploy, e)
      end
    end
  end
end
