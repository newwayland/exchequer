# frozen_string_literal: true

require 'log'

describe Log do
  let(:log_io) { StringIO.new }
  let(:filename) { 'fake.log' }

  before do
    # Intercept File.open and return a StringIO instead
    allow(File).to receive(:open).with(filename, mode: 'w').and_return(log_io)
  end

  describe '#initialize' do
    it 'opens a log file' do
      logger = described_class.new(filename)
      expect(log_io).not_to be_closed
      logger.close
    end
  end

  describe '#write' do
    it 'writes log messages with correct timestamp format' do
      logger = described_class.new(filename)
      timestamp = Time.new(2025, 2, 17, 8, 30) # Example timestamp

      logger.write(timestamp, 'Test log entry')

      log_contents = log_io.string
      expect(log_contents).to match(/\A\d{2}:\w{3} \d{2}:\d{2}: Test log entry\n\z/)
      logger.close
    end
  end

  describe '#close' do
    it 'closes the log file' do
      logger = described_class.new(filename)
      logger.close
      expect(log_io).to be_closed
    end
  end
end
