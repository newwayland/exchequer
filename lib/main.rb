# frozen_string_literal: true

require_relative 'simulation_controller'
File.umask(0)
SimulationController.new(duration_days: 5).run
