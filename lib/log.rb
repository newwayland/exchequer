# frozen_string_literal: true

# Log provides simple file-based logging with timestamped entries.
class Log
  def initialize(filename)
    @logfile = File.open(filename, mode: 'w')
    @logfile.sync = true
  end

  def write(timestamp, msg)
    @logfile.puts("#{timestamp.strftime('%V:%a %H:%M')}: #{msg}")
  end

  def close
    @logfile.close
  end
end
