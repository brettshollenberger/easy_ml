require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Splitters::DateSplitter do
  include ModelSpecHelper

  let(:dataset) { loans_dataset }

  it "splits files by date" do
    mock_s3_download(single_file_dir)
    mock_s3_upload

    dataset.refresh!

    expect(dataset.train.count).to be > 0
    expect(dataset.test.count).to be > 0
    expect(dataset.valid.count).to be > 0
    expect(dataset.data.count).to eq(dataset.train.count + dataset.test.count + dataset.valid.count)
  end

  it "respects the date boundaries for splits" do
    mock_s3_download(single_file_dir)
    mock_s3_upload

    dataset.refresh!

    test_start = dataset.splitter.splits[1]
    valid_start = dataset.splitter.splits[0]

    expect(dataset.train(all_columns: true)["date"].max).to be < valid_start
    expect(dataset.valid(all_columns: true)["date"].min).to be >= valid_start
    expect(dataset.valid(all_columns: true)["date"].max).to be < test_start
    expect(dataset.test(all_columns: true)["date"].min).to be >= test_start
  end

  it "splits targets" do
    mock_s3_download(single_file_dir)
    mock_s3_upload

    dataset.refresh!
    dataset.columns.find_by(name: "rev").update(is_target: true)
    dataset.refresh!
    _, ys = dataset.train(split_ys: true)
    expect(ys["rev"]).to eq dataset.train["rev"]
  end
end
