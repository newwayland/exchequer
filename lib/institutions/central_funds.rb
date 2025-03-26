# frozen_string_literal: true

module Institutions
  # CentralFunds manages the central government accounts and their
  # operations in the financial simulation.
  # It serves as the primary interface to the NLF deposit system, handling account
  # creation and management for various parts of the Excequer Pyramid.
  class CentralFunds
    def current_time(...)
      @treasury_deposits.current_time(...)
    end

    def advance_time(...)
      @treasury_deposits.advance_time(...)
    end

    def institutions(...)
      @treasury_deposits.institutions(...)
    end

    def shutdown(...)
      @treasury_deposts.shutdown(...)
    end

    # Initialize a new central funds system
    #
    # @param name [String] the name of the central funds system
    # @param simulation_time [Time] the starting time for the simulation
    # @param logger [Object] logging facility that responds to <<
    # @return [CentralFunds] a new instance of the central funds system
    #
    # @api public
    def initialize(name:, simulation_time:, logger:)
      @treasury_deposits = Banking::AuthorisedDepositSystem.new(name: name, simulation_time: simulation_time,
                                                                logger: logger)
      @logger = logger
    end

    # Updates the institutions directory and creates necessary accounts
    #
    # This method must be called after initialization and before any
    # financial operations are performed. It establishes the network
    # of accounts required for the central banking system.
    #
    # @param directory [Hash] the institutions directory with references to all financial entities
    # @return [Boolean] true if directory was stored and accounts were created successfully
    #
    # @api public
    def update_institutions_directory(directory)
      @treasury_deposits.update_institutions_directory(directory)
      create_accounts
      true
    end

    private

    # Creates all accounts required for the central banking system
    #
    # Delegates to the CentralFundsSetup module to create and authorize
    # the full network of accounts across various institutions.
    #
    # @return [Hash] a structured hash of all created accounts
    #
    # @api private
    def create_accounts
      @funds = CentralFundsSetup.create_accounts(method(:log_event), @treasury_deposits)
    end

    # Records an event in the system log
    #
    # @param message [String] the event message to be logged
    #
    # @api private
    def log_event(message)
      @logger << Log.format(current_time, message)
    end
  end
end
