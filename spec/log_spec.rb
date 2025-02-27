# frozen_string_literal: true

require 'log'

describe Log do
  filename = 'fake.log'
  let(:log_io) { StringIO.new }

  before do
    # Intercept File.open and return a StringIO instead
    allow(File).to receive(:open).with(filename, mode: 'w').and_return(log_io)
  end

  describe '#initialize' do
    it 'opens a log file' do
      described_class.new(filename)
      expect(File).to have_received(:open)
      expect(log_io).not_to be_closed
    end
  end

  describe '#<<' do
    it 'writes log messages with correct timestamp format' do
      logger = described_class.new(filename)
      test_string = 'Test entry'
      logger << test_string
      log_contents = log_io.string
      expect(log_contents).to eq(test_string)
    end
  end

  describe '.format' do
    it 'formats log entries correctly' do
      timestamp = Time.new(2025, 2, 27, 14, 30) # Example fixed timestamp
      formatted = described_class.format(timestamp, 'Sample log')
      expect(formatted).to eq("09:Thu 14:30: Sample log\n")
    end
  end

  describe '#close' do
    it 'closes the logfile' do
      logger = described_class.new(filename)
      logger.close
      expect { logger << 'Should fail' }.to raise_error(IOError)
    end
  end
end
