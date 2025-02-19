# frozen_string_literal: true

require 'date'
require_relative 'log'

class SimulationController
  def initialize(duration_days)
    @start_date = next_monday
    @duration_days = duration_days
    @logger = Log.new('log/simulation.log')
  end

  def run
    @simtime = timestamp(@start_date, '08:00')
    @logger.write(@simtime, 'Starting simulation')
    @simtime = timestamp(@start_date, '16:30')
  ensure
    @logger.write(@simtime, 'Starting simulation')
    @logger.close
  end

  private

  def next_monday
    Date.today + ((1 - Date.today.wday) % 7 + 7)
  end

  def timestamp(date, time)
    time_split = time.split(':')
    Time.new(date.year, date.month, date.day, time_split[0].to_i, time_split[1].to_i)
  end
end
