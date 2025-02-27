# frozen_string_literal: true

module Banking
  # Raised when attempting to access an invalid or non-existent account
  class InvalidAccount < StandardError; end

  # DepositSystem manages bank accounts and provides core banking operations.
  # It maintains account balances, processes transfers, and tracks transaction history.
  #
  # @api public
  class DepositSystem
    attr_reader :name, :accounts, :current_time

    # Initializes a new banking system instance
    #
    # @param name [String] the name of the banking system
    # @param simulation_time [Time] the initial system time
    # @param logger [Log] the logger instance for system events
    #
    # @api public
    def initialize(name, simulation_time, logger)
      @name = name
      @current_time = simulation_time
      @logger = logger
      @accounts = Hash.new { |_, key| raise InvalidAccount, "Account Number not found: #{key}" }
    end

    # Updates the system time to a new point in time
    #
    # @param new_time [Time] the time to advance to
    # @raise [ArgumentError] if new_time is nil or earlier than current time
    #
    # @api public
    def advance_time(new_time)
      raise ArgumentError, 'New time must be provided' if new_time.nil?
      raise ArgumentError, 'Time cannot move backwards' if new_time < @current_time

      @current_time = new_time
      log_event('Clock advanced')
      @current_time
    end

    # Creates a new credit normal bank account (standard account)
    #
    # @param name [String] the account holder's name
    # @param initial_balance [Numeric] optional initial deposit amount
    # @return [String] the unique account identifier
    # @raise [ArgumentError] if name is blank
    #
    # @api public
    def create_account(name:, initial_balance: 0)
      raise ArgumentError, 'Account name cannot be blank' if name.to_s == ''

      create_specific_account(Account::CreditNormal, name, initial_balance)
    end

    # Creates a new debit normal bank account (mirror account)
    #
    # @param name [String] the account holder's name
    # @param initial_balance [Numeric] optional initial deposit amount
    # @return [String] the unique account identifier
    # @raise [ArgumentError] if name is blank
    #
    # @api public
    def create_mirror_account(name:, initial_balance: 0)
      raise ArgumentError, 'Account name cannot be blank' if name.to_s == ''

      create_specific_account(Account::DebitNormal, "#{name} (M)", -initial_balance)
    end

    # Transfers money between accounts
    #
    # @param from [String] source account ID
    # @param to [String] destination account ID
    # @param amount [Numeric] amount to transfer
    # @param reference [String] optional transfer reference note
    # @return [Boolean] true if transfer succeeds
    # @raise [ArgumentError] if source and destination are same
    # @raise [InvalidAccount] if either account doesn't exist
    #
    # @api public
    def transfer(from:, to:, amount:, reference: '')
      raise ArgumentError, 'Source and destination accounts cannot be the same' if from == to

      source = @accounts[from]
      destination = @accounts[to]

      source_transfer(source, destination.name, amount, reference)
      destination_transfer(destination, source.name, amount, reference)

      log_event("Transfer completed: #{amount} from #{from} to #{to}: #{reference}")
      true
    rescue ArgumentError => e
      log_event("Transfer failed: #{amount} from #{from} to #{to}: #{e.message}")
      raise
    end

    # Retrieves current balance of an account
    #
    # @param account_id [String] the account to query
    # @return [Numeric] the current balance
    # @raise [InvalidAccount] if account doesn't exist
    #
    # @api public
    def balance(account_id)
      @accounts[account_id].balance
    end

    # Retrieves transaction history for an account
    #
    # @param account_id [String] the account to query
    # @return [Array<Transaction>] list of transactions in chronological order
    # @raise [InvalidAccount] if account doesn't exist
    #
    # @api public
    def transactions(account_id)
      @accounts[account_id].transactions
    end

    # Retrieves the name associated with an account
    #
    # @param account_id [String] the account to query
    # @return [String] the account holder's name
    # @raise [InvalidAccount] if account doesn't exist
    #
    # @api public
    def account_name(account_id)
      @accounts[account_id].name
    end

    private

    # Creates a specific type of account
    #
    # @param account_class [Class] the account class to instantiate
    # @param name [String] the account holder's name
    # @param initial_balance [Numeric] initial deposit amount
    # @return [String] the unique account identifier
    # @raise [ArgumentError] if name is blank
    #
    # @api private
    def create_specific_account(account_class, name, initial_balance)
      account = account_class.new(name)
      @accounts[account.id] = account
      credit_initial_balance(account, initial_balance)
      log_event("Account created: #{account.id} - #{name}")
      account.id
    end

    # Processes debit operation for source account during transfer
    #
    # @param source [Account] source account
    # @param destination_name [String] name of destination account
    # @param amount [Numeric] transfer amount
    # @param reference [String] transfer reference
    #
    # @api private
    def source_transfer(source, destination_name, amount, reference)
      description = "Transfer to #{destination_name} - #{reference}"
      source.debit(@current_time, amount, description)
    end

    # Processes credit operation for destination account during transfer
    #
    # @param destination [Account] destination account
    # @param source_name [String] name of source account
    # @param amount [Numeric] transfer amount
    # @param reference [String] transfer reference
    #
    # @api private
    def destination_transfer(destination, source_name, amount, reference)
      description = "Bank credit from #{source_name} - #{reference}"
      destination.credit(@current_time, amount, description)
    end

    # Credits initial balance to newly created account
    #
    # @param destination [Account] the new account
    # @param amount [Numeric] initial balance amount
    #
    # @api private
    def credit_initial_balance(destination, amount)
      if amount.positive?
        destination.credit(@current_time, amount, 'Initial balance')
      elsif amount.negative?
        destination.debit(@current_time, -amount, 'Initial balance')
      end
    end

    # Records an event in the system log
    #
    # @param message [String] the event message
    #
    # @api private
    def log_event(message)
      @logger << Log.format(@current_time, message)
    end
  end
end
