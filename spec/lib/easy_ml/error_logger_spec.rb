require 'spec_helper'

RSpec.describe EasyML::ErrorLogger do
  describe '.error' do
    context 'when ROLLBAR_ACCESS_TOKEN is defined' do
      before do
        allow(ENV).to receive(:[]).with("ROLLBAR_ACCESS_TOKEN").and_return("test-token")
      end

      it 'calls Rollbar.error with the error' do
        error = StandardError.new("test error")
        expect(Rollbar).to receive(:error).with(error)
        
        described_class.error(error)
      end
    end
  end
end
