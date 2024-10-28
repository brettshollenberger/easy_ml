require "spec_helper"

RSpec.describe EasyML::RetrainingJob do
  let(:valid_attributes) do
    {
      model: "test_model",
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
      }
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

  describe ".current" do
    let!(:inactive_job) do
      described_class.create!(valid_attributes.merge(active: false))
    end

    let!(:active_job) do
      described_class.create!(valid_attributes.merge(active: true))
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
  end

  describe "#should_run?" do
    let(:job) { described_class.create!(valid_attributes.merge(frequency: frequency, at: at)) }
    let(:at) { 2 }

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
        EasyML::RetrainingRun.create!(
          retraining_job: job,
          status: "pending",
          created_at: current_time - 15.minutes
        )
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
          EasyML::RetrainingRun.create!(
            retraining_job: job,
            status: "pending",
            created_at: Time.current - 1.hour
          )
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
          EasyML::RetrainingRun.create!(
            retraining_job: job,
            status: "pending",
            created_at: Time.current - 1.hour
          )
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
          EasyML::RetrainingRun.create!(
            retraining_job: job,
            status: "pending",
            created_at: Time.current - 1.hour
          )
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
end
