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
    belongs_to :model_version, class_name: "EasyML::ModelHistory", optional: true, foreign_key: :model_history_id

    validates :status, presence: true
    after_initialize :set_defaults, if: :new_record?
    before_save :set_model_file, if: :new_record?
    validates :status, presence: true, inclusion: { in: %w[pending running success failed] }

    scope :latest, -> { select("DISTINCT ON (model_id) *").order("model_id, id DESC") }

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
      lock_deploy do
        update(status: "running")
        EasyML::Event.create_event(self, "started")

        if identical_deploy.present?
          self.model_file = identical_deploy.model_file
          self.model_version = identical_deploy.model_version
        else
          if model_file.present?
            model.model_file = model_file
          end
          model.load_model
          self.model_version = model.actually_deploy
        end

        EasyML::Deploy.transaction do
          update(model_history_id: self.model_version.id, snapshot_id: self.model_version.snapshot_id, status: :success)
          model.retraining_runs.where(status: :deployed).update_all(status: :success)
          retraining_run.update(model_history_id: self.model_version.id, snapshot_id: self.model_version.snapshot_id, deploy_id: id, status: :deployed, is_deploying: false)
        end

        model_version.tap do
          EasyML::Event.create_event(self, "success")
        end
      end
    end

    alias_method :rollback, :deploy

    def unlock!
      Support::Lockable.unlock!(lock_key)
    end

    def lock_deploy
      with_lock do |client|
        yield
      end
    end

    def identical_deploy
      EasyML::Deploy.where(retraining_run_id: retraining_run_id).
        where.not(id: id).where(status: :success).limit(1).first
    end

    private

    def with_lock
      EasyML::Support::Lockable.with_lock(lock_key, stale_timeout: 60, resources: 1) do |client|
        yield client
      end
    end

    def lock_key
      "deploy:#{self.model.name}:#{self.model.id}"
    end

    def set_defaults
      self.status ||= :pending
    end

    def set_model_file
      self.model_file ||= retraining_run.model_file
    end
  end
end
