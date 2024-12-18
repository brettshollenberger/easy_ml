require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Splitters::PredefinedSplitter do
  include ModelSpecHelper

  let(:dataset) { predefined_dataset }
  let(:reader) { EasyML::Data::PolarsReader.new }

  it "assigns files to the correct splits" do
    mock_s3_download(predefined_splits_dir)
    mock_s3_upload

    dataset.refresh!

    train_files = Dir.glob(predefined_splits_dir.join("train*.csv")).sort
    test_files = Dir.glob(predefined_splits_dir.join("test*.csv")).sort
    valid_files = Dir.glob(predefined_splits_dir.join("valid*.csv")).sort

    expect(dataset.raw.train(all_columns: true)).to eq(reader.query(train_files))
    expect(dataset.raw.test(all_columns: true)).to eq(reader.query(test_files))
    expect(dataset.raw.valid(all_columns: true)).to eq(reader.query(valid_files))
  end

  context "when no files are specified" do
    it "raises a validation error" do
      dataset.splitter.update(train_files: [])
      expect { dataset.refresh! }.to raise_error(
        ActiveModel::ValidationError,
        /Train files can't be blank/
      )
    end
  end
end
