require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::RetrainingJob do
  include ModelSpecHelper
  let(:root_dir) do
    Rails.root
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Polars Datasource",
      datasource_type: :polars,
      df: df
    )
  end

  let(:dataset) do
    dataset_config[:datasource] = datasource
    EasyML::Dataset.create(
      name: "Dataset",
      **dataset_config
    )
  end

  let(:model_name) do
    "My Model"
  end
  let(:model) do
    model_config[:name] = model_name
    model_config[:task] = "regression"
    EasyML::Model.create(**model_config).tap do |model|
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote
    end
  end
  let(:valid_attributes) do
    {
      model: model.name,
      frequency: "day",
      at: 2,
      active: true,
      tuner_config: {
        n_trials: 5,
        objective: :mean_absolute_error,
        config: {
          learning_rate: { min: 0.01, max: 0.1 },
          n_estimators: { min: 1, max: 2 },
          max_depth: { min: 1, max: 5 }
        }
      },
      locked_at: nil
    }
  end

  describe "validations" do
    it "requires model" do
      job = described_class.new(valid_attributes.except(:model))
      expect(job).not_to be_valid
      expect(job.errors[:model]).to include("can't be blank")
    end

    it "requires frequency" do
      job = described_class.new(valid_attributes.except(:frequency))
      expect(job).not_to be_valid
      expect(job.errors[:frequency]).to include("can't be blank")
    end

    it "requires at" do
      job = described_class.new(valid_attributes.except(:at))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("can't be blank")
    end

    it "validates frequency inclusion" do
      job = described_class.new(valid_attributes.merge(frequency: "invalid"))
      expect(job).not_to be_valid
      expect(job.errors[:frequency]).to include("is not included in the list")
    end

    it "validates at is between 0 and 23" do
      job = described_class.new(valid_attributes.merge(at: 24))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("must be less than 24")

      job = described_class.new(valid_attributes.merge(at: -1))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("must be greater than or equal to 0")
    end

    it "validates model uniqueness" do
      described_class.create!(valid_attributes)
      duplicate_job = described_class.new(valid_attributes)

      expect(duplicate_job).not_to be_valid
      expect(duplicate_job.errors[:model]).to include("already has a retraining job")
    end

    it "validates model existence and state" do
      job = described_class.new(valid_attributes.merge(model: "nonexistent_model"))
      expect(job).not_to be_valid
      expect(job.errors[:model]).to include("does not exist or is not in inference state")
    end

    it "is valid when model exists and is in inference state" do
      job = described_class.new(valid_attributes)
      expect(job).to be_valid
    end
  end

  describe "associations" do
    let(:job) { described_class.create!(valid_attributes) }

    it "has many retraining runs" do
      run = EasyML::RetrainingRun.create!(retraining_job: job, status: "pending")
      expect(job.retraining_runs).to include(run)
    end

    it "destroys dependent retraining runs" do
      EasyML::RetrainingRun.create!(retraining_job: job, status: "pending")
      expect { job.destroy }.to change(EasyML::RetrainingRun, :count).by(-1)
    end
  end

  describe "locking" do
    let(:job) { described_class.create!(valid_attributes) }

    describe "#locked?" do
      it "returns false when not locked" do
        expect(job.locked?).to be false
      end

      it "returns true when locked" do
        job.update!(locked_at: Time.current)
        expect(job.locked?).to be true
      end

      it "returns false when lock has expired" do
        job.update!(locked_at: 7.hours.ago)
        expect(job.locked?).to be false
      end
    end

    describe "#lock!" do
      it "sets locked_at timestamp" do
        expect { job.lock! }.to change { job.locked_at }.from(nil)
      end

      it "returns false if already locked" do
        job.lock!
        expect(job.lock!).to be false
      end
    end

    describe "#unlock!" do
      it "clears locked_at timestamp" do
        job.lock!
        expect { job.unlock! }.to change { job.locked_at }.to(nil)
      end
    end
  end

  describe ".current" do
    let!(:active_job) do
      described_class.create!(valid_attributes.merge(active: true))
    end
    let!(:inactive_job) do
      job2 = active_job.dup
      job2.model = "Another One"
      allow(job2).to receive(:model_must_exist).and_return(true)
      job2.active = false
      job2.save
      job2
    end

    it "only includes active jobs" do
      expect(described_class.current).not_to include(inactive_job)
    end

    it "includes jobs that should run" do
      allow(active_job).to receive(:should_run?).and_return(true)
      expect(described_class.current).to include(active_job)
    end

    it "excludes jobs that should not run" do
      allow_any_instance_of(EasyML::RetrainingJob).to receive(:should_run?).and_return(false)
      expect(described_class.current).not_to include(active_job)
    end

    it "excludes locked jobs" do
      active_job.update!(locked_at: Time.current)
      expect(described_class.current).not_to include(active_job)
    end

    it "includes jobs with expired locks" do
      active_job.update!(locked_at: 7.hours.ago)
      allow(active_job).to receive(:should_run?).and_return(true)
      expect(described_class.current).to include(active_job)
    end
  end

  describe "#should_run?" do
    let(:job) { described_class.create!(valid_attributes.merge(frequency: frequency, at: at)) }
    let(:at) { 2 }
    let(:frequency) { "day" } # Add this default frequency

    context "when job is locked" do
      before do
        job.update!(locked_at: Time.current)
      end

      it "returns false" do
        expect(job.should_run?).to be false
      end
    end

    context "when job has never run" do
      let(:frequency) { "day" }

      it "returns true" do
        expect(job.should_run?).to be true
      end
    end

    context "with hourly frequency" do
      let(:frequency) { "hour" }
      let(:current_time) { Time.current.beginning_of_hour + 30.minutes }

      before do
        allow(Time).to receive(:current).and_return(current_time)
      end

      it "returns true when last run was in previous hour" do
        job.update!(last_run_at: current_time - 2.hours)
        expect(job.should_run?).to be true
      end

      it "returns false when already run in current hour" do
        job.update!(last_run_at: current_time - 15.minutes)
        expect(job.should_run?).to be false
      end
    end

    context "with daily frequency" do
      let(:frequency) { "day" }

      context "when current hour matches at" do
        before do
          allow(Time).to receive(:current).and_return(Time.current.change(hour: at))
        end

        it "returns true when last run was yesterday" do
          job.update!(last_run_at: 1.day.ago)
          expect(job.should_run?).to be true
        end

        it "returns false when already run today" do
          job.update(last_run_at: Time.current - 1.hour)
          expect(job.should_run?).to be false
        end
      end

      context "when current hour does not match at" do
        before do
          allow(Time).to receive(:current).and_return(Time.current.change(hour: at + 1))
        end

        it "returns false" do
          job.update!(last_run_at: 1.day.ago)
          expect(job.should_run?).to be false
        end
      end
    end

    context "with weekly frequency" do
      let(:frequency) { "week" }
      let(:sunday_at_2am) { (Time.current.beginning_of_week - 1.day).change(hour: at) }

      context "when Sunday at specified hour" do
        before do
          allow(Time).to receive(:current).and_return(sunday_at_2am)
        end

        it "returns true when last run was last week" do
          job.update!(last_run_at: 1.week.ago)
          expect(job.should_run?).to be true
        end

        it "returns false when already run this week" do
          job.update(last_run_at: Time.current - 1.hour)
          expect(job.should_run?).to be false
        end
      end

      context "when not Sunday" do
        before do
          allow(Time).to receive(:current).and_return(sunday_at_2am + 1.day)
        end

        it "returns false" do
          job.update!(last_run_at: 1.week.ago)
          expect(job.should_run?).to be false
        end
      end
    end

    context "with monthly frequency" do
      let(:frequency) { "month" }
      let(:first_day_at_2am) { Time.current.beginning_of_month.change(hour: at) }

      context "when first day of month at specified hour" do
        before do
          allow(Time).to receive(:current).and_return(first_day_at_2am)
        end

        it "returns true when last run was last month" do
          job.update!(last_run_at: 1.month.ago)
          expect(job.should_run?).to be true
        end

        it "returns false when already run this month" do
          job.update(last_run_at: Time.current - 1.hour)
          expect(job.should_run?).to be false
        end
      end

      context "when not first day of month" do
        before do
          allow(Time).to receive(:current).and_return(first_day_at_2am + 1.day)
        end

        it "returns false" do
          job.update!(last_run_at: 1.month.ago)
          expect(job.should_run?).to be false
        end
      end
    end
  end

  describe "#should_tune?" do
    let(:job) do
      described_class.create!(valid_attributes.merge(
                                tuning_frequency: tuning_frequency,
                                at: at
                              ))
    end
    let(:at) { 2 }
    let(:tuning_frequency) { "week" }

    it "returns false when tuning_frequency is nil" do
      job.update!(tuning_frequency: nil)
      expect(job.should_tune?).to be false
    end

    it "returns true when never tuned before" do
      expect(job.should_tune?).to be true
    end

    context "with weekly tuning frequency" do
      let(:sunday_at_2am) { (Time.current.beginning_of_week - 1.day).change(hour: at) }

      before do
        allow(Time).to receive(:current).and_return(sunday_at_2am)
      end

      it "returns true when last tuning was over a week ago" do
        job.update!(last_tuning_at: 2.weeks.ago)
        expect(job.should_tune?).to be true
      end

      it "returns false when last tuning was this week" do
        job.update!(last_tuning_at: 1.hour.ago)
        expect(job.should_tune?).to be false
      end
    end
  end
end
