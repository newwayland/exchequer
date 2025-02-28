# frozen_string_literal: true

require 'date'
require 'logger'
require_relative 'log'
require_relative 'institutions'

class SimulationController
  def initialize(duration_days)
    @institutions = {}
    @start_date = next_monday
    @duration_days = duration_days
    @logger = Logger.new($stdout)
  end

  def run
    @simtime = timestamp(@start_date, '08:00')
    log_event('Starting simulation')
    register_institutions
    distribute_directory
    @simtime = timestamp(@start_date, '16:30')
    update_times
    stop_simulation
    log_event('Stopping simulation')
  end

  private

  def stop_simulation
    @institutions.each_value(&:shutdown)
  end

  def update_times
    @institutions.each_value { |inst| inst.advance_time(@simtime) }
  end

  def register_institutions
    @institutions[:boe] =
      Banking::AuthorisedDepositSystem.new(name: 'Bank of England', simulation_time: @simtime, logger: @logger)
    @institutions[:gbs] =
      Banking::AuthorisedDepositSystem.new(name: 'Government Banking Service', simulation_time: @simtime,
                                           logger: @logger)
    @institutions[:efa] =
      Institutions::CentralFunds.new(name: 'Exchequer Funds and Accounts', simulation_time: @simtime, logger: @logger)
  end

  def distribute_directory
    registration_list = @institutions.clone
    @institutions.each_value do |inst|
      inst.update_institutions_directory(registration_list)
    end
  end

  def next_monday
    date = Date.parse('Monday')
    date + (date > Date.today ? 0 : 7)
  end

  def timestamp(date, time)
    time_split = time.split(':')
    Time.new(date.year, date.month, date.day, time_split[0].to_i, time_split[1].to_i)
  end

  def log_event(msg)
    @logger << Log.format(@simtime, msg)
  end
end
