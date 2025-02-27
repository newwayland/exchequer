# frozen_string_literal: true

require 'forwardable'

# Log provides simple file-based logging with timestamped entries.
class Log
  extend Forwardable
  def_delegators :@logfile, :close, :<<

  def initialize(filename)
    @logfile = File.open(filename, mode: 'w')
    @logfile.sync = true
  end

  def self.format(timestamp, msg)
    "#{timestamp.strftime('%V:%a %H:%M')}: #{msg}\n"
  end
end
