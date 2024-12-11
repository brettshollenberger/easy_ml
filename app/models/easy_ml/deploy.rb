# == Schema Information
#
# Table name: easy_ml_deploys
#
#  id                :bigint           not null, primary key
#  model_id          :bigint
#  retraining_run_id :bigint
#  model_file_id     :bigint
#  status            :string           not null
#  trigger           :string           default("manual")
#  stacktrace        :text
#  locked_at         :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
module EasyML
  class Deploy < ActiveRecord::Base
    self.table_name = "easy_ml_deploys"
    include EasyML::Concerns::Lockable

    belongs_to :model, class_name: "EasyML::Model"
    belongs_to :model_file, class_name: "EasyML::ModelFile"
    belongs_to :retraining_run, class_name: "EasyML::RetrainingRun"

    after_create :enqueue_deploy
    validates :status, presence: true
    after_initialize :set_default_status, if: :new_record?
    validates :status, presence: true, inclusion: { in: %w[pending running success failed] }

    def unlocked?
      EasyML::Deploy.where(model_id: model_id).where.not(locked_at: nil).where(status: ["pending", "running"]).empty?
    end

    def locked?
      !unlocked?
    end

    def deploy
      if model_file.present?
        model.model_file = model_file
      end
      model.load_model
      model.deploy
    end

    alias_method :rollback, :deploy

    def enqueue_deploy
      EasyML::DeployWorker.perform_async(id)
    end

    private

    def set_default_status
      self.status ||= :pending
    end
  end
end
