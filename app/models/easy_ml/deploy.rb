# == Schema Information
#
# Table name: easy_ml_deploys
#
#  id                :bigint           not null, primary key
#  model_id          :bigint
#  model_history_id  :bigint
#  retraining_run_id :bigint
#  model_file_id     :bigint
#  status            :string           not null
#  trigger           :string           default("manual")
#  stacktrace        :text
#  snapshot_id       :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
module EasyML
  class Deploy < ActiveRecord::Base
    self.table_name = "easy_ml_deploys"

    belongs_to :model, class_name: "EasyML::Model"
    belongs_to :model_file, class_name: "EasyML::ModelFile", optional: true
    belongs_to :retraining_run, class_name: "EasyML::RetrainingRun"
    belongs_to :deployed_model, class_name: "EasyML::ModelHistory", optional: true, foreign_key: :model_history_id

    validates :status, presence: true
    after_initialize :set_default_status, if: :new_record?
    validates :status, presence: true, inclusion: { in: %w[pending running success failed] }

    def unlocked?
      EasyML::Deploy.where(model_id: model_id).where.not(locked_at: nil).where(status: ["pending", "running"]).empty?
    end

    def locked?
      !unlocked?
    end

    def deploy(async: true)
      if async
        EasyML::DeployJob.perform_later(id)
      else
        actually_deploy
      end
    end

    def actually_deploy
      key = "deploy:#{self.model.name}:#{self.model.id}"
      EasyML::Support::Lockable.with_lock_client(key, stale_timeout: 60, resources: 1) do |client|
        client.lock do
          update(status: "running")
          EasyML::Event.create_event(self, "started")

          if model_file.present?
            model.model_file = model_file
          end
          model.load_model
          deployed_model = model.deploy

          EasyML::Deploy.transaction do
            update(model_history_id: deployed_model.id, snapshot_id: deployed_model.snapshot_id, status: :success)
            model.retraining_runs.where(status: :deployed).update_all(status: :success)
            retraining_run.update(model_history_id: deployed_model.id, snapshot_id: deployed_model.snapshot_id, deploy_id: id, status: :deployed, is_deploying: false)
          end

          deployed_model.tap do
            EasyML::Event.create_event(self, "success")
          end
        end
      end
    end

    alias_method :rollback, :deploy

    private

    def set_default_status
      self.status ||= :pending
    end
  end
end
