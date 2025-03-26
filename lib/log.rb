# frozen_string_literal: true

# Log provides simple file-based logging with timestamped entries.
class Log
  def close(...)
    @logfile.close(...)
  end

  def <<(...)
    @logfile.<<(...)
  end

  def initialize(filename)
    @logfile = File.open(filename, mode: 'w')
    @logfile.sync = true
  end

  def self.format(timestamp, msg)
    "#{timestamp.strftime('%V:%a %H:%M')}: #{msg}\n"
  end
end
