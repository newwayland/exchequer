# frozen_string_literal: true

require 'forwardable'
require 'set'

module Banking
  # Custom error for unauthorised access attempts
  class UnauthorisedAccessError < StandardError
    def initialize(entity = nil, account_id = nil)
      message = 'Unauthorised access to account'
      message += " #{account_id}" if account_id
      message += " by #{entity}" if entity
      super(message)
    end
  end

  # AuthorisedDepositSystem decorates the DepositSystem, adding authorisation and institutions directory capabilities
  #
  # @api public
  class AuthorisedDepositSystem
    extend Forwardable

    # Methods to delegate directly to the underlying DepositSystem
    def_delegators :@deposit_system, :current_time, :advance_time

    attr_reader :institutions

    # @param name [String] bank name
    # @param simulation_time [Time] starting time
    # @param logger [Log] logger instance
    # @param authorisations [Hash] initial auth mappings
    def initialize(name:, simulation_time:, logger:, authorisations: {})
      @deposit_system = DepositSystem.new(name, simulation_time, logger)
      @logger = logger
      @authorisations = authorisations
      @authorisations.default_proc = ->(hash, key) { hash[key] = Set.new }
      @institutions = {}
    end

    # Stores the institutions directory
    #
    # @param directory [Hash] the institutions directory
    # @return [Boolean] true if directory was stored
    #
    # @api public
    def update_institutions_directory(directory)
      log_event('Received Institution Directory')
      @institutions = directory
      true
    end

    # Creates a new account and authorises the entity
    #
    # @param entity [Object] the entity creating the account
    # @param name [String] account name
    # @param initial_balance [Numeric] initial balance
    # @return [String] the account ID
    #
    # @api public
    def create_account(entity:, name:, initial_balance: 0)
      account_id = @deposit_system.create_account(name: name, initial_balance: initial_balance)
      @authorisations[entity] << account_id
      account_id
    end

    # Creates a new mirror account and authorises the entity
    #
    # @param entity [Object] the entity creating the account
    # @param name [String] account name
    # @param initial_balance [Numeric] initial balance
    # @return [String] the account ID
    #
    # @api public
    def create_mirror_account(entity:, name:, initial_balance: 0)
      account_id = @deposit_system.create_mirror_account(name: name, initial_balance: initial_balance)
      @authorisations[entity] << account_id
      account_id
    end

    # Transfers money between accounts if entity is authorised
    #
    # @param entity [Object] the entity requesting the transfer
    # @param from [String] source account ID
    # @param to [String] destination account ID
    # @param amount [Numeric] amount to transfer
    # @param reference [String] transfer reference
    # @return [Boolean] true if successful
    # @raise [UnauthorisedAccessError] if unauthorised
    #
    # @api public
    def transfer(entity:, from:, to:, amount:, reference: nil)
      authorise!(entity, from)
      @deposit_system.transfer(from: from, to: to, amount: amount, reference: reference)
    end

    # Gets the balance of an account if entity is authorised
    #
    # @param entity [Object] the entity requesting the balance
    # @param account_id [String] the account ID
    # @return [Numeric] the account balance
    # @raise [UnauthorisedAccessError] if unauthorised
    #
    # @api public
    def balance(entity:, account_id:)
      authorise!(entity, account_id)
      @deposit_system.balance(account_id)
    end

    # Gets transactions for an account if entity is authorised
    #
    # @param entity [Object] the entity requesting transactions
    # @param account_id [String] the account ID
    # @return [Array] list of transactions
    # @raise [UnauthorisedAccessError] if unauthorised
    #
    # @api public
    def transactions(entity:, account_id:)
      authorise!(entity, account_id)
      @deposit_system.transactions(account_id)
    end

    # authorises another entity to access an account
    #
    # @param owner [Object] the account owner
    # @param account_id [String] the account ID
    # @param entity [Object] the entity to authorise
    # @return [Boolean] true if successful
    # @raise [UnauthorisedAccessError] if owner is not authorised
    #
    # @api public
    def authorise_entity(owner:, account_id:, entity:)
      authorise!(owner, account_id)
      @authorisations[entity] << account_id
      true
    end

    # Cleans up resources
    #
    # @api public
    def shutdown
      log_event('Shutting down')
    end

    private

    # Checks if an entity is authorised for an account
    #
    # @param entity [Object] the entity to check
    # @param account_id [String] the account ID
    # @return [Boolean] true if authorised
    # @raise [UnauthorisedAccessError] if unauthorised
    #
    # @api private
    def authorise!(entity, account_id)
      return true if @authorisations[entity].include?(account_id)

      err = UnauthorisedAccessError.new(entity, account_id)
      log_event(err.message)
      raise err
    end

    # Records an event in the system log
    #
    # @param message [String] the event message
    #
    # @api private
    def log_event(message)
      @logger << Log.format(current_time, message)
    end
  end
end
