# frozen_string_literal: true

require 'securerandom'
require_relative 'account'
require_relative 'log'

# Banking module provides a comprehensive banking simulation system with support for
# account management, transactions, and time-based operations. It implements a
# message-based architecture for handling banking operations securely.
#
# @example Creating a new bank and performing operations
#   bank = Banking::DepositSystem.new('MyBank', Time.now, logger)
#   account = bank.create_account(name: 'John Doe', initial_balance: 1000)
#   bank.transfer(from: account, to: other_account, amount: 500)
#
# @api public
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
      log_event("Clock advanced to #{@current_time}")
    end

    # Creates a new bank account
    #
    # @param name [String] the account holder's name
    # @param initial_balance [Numeric] optional initial deposit amount
    # @return [String] the unique account identifier
    # @raise [ArgumentError] if name is blank
    #
    # @api public
    def create_account(name:, initial_balance: 0)
      raise ArgumentError, 'Account name cannot be blank' if name.to_s == ''

      account = Account::CreditNormal.new(name)
      @accounts[account.id] = account
      credit_initial_balance(account, initial_balance)
      log_event("Account created: #{account.id} - #{name}")
      account.id
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
      @logger.write(@current_time, message)
    end
  end

  # Messages module contains all message types used for bank operations
  #
  # @api public
  module Messages
    # Base class for all banking messages
    #
    # @abstract Subclass and implement {#authorized?} to create concrete message types
    class Message
      attr_reader :sender

      # @param sender [Object] the originator of the message
      def initialize(sender:)
        @sender = sender
        Ractor.make_shareable(self)
      end

      # Checks if the message is authorized
      #
      # @param auth [Array<String>] list of authorized account IDs
      # @return [Boolean] true if authorized
      #
      # @api public
      def authorized?(_auth)
        raise NotImplementedError, 'Subclasses must implement `authorized?`'
      end
    end

    # Represents the result of processing a banking message
    #
    # @api public
    class Result
      attr_reader :status, :data

      # Creates a success result
      #
      # @param data [Object] the success data
      # @return [Result] success result instance
      #
      # @api public
      def self.success(data)
        new(:ok, data)
      end

      # Creates an error result
      #
      # @param message [String] the error message
      # @return [Result] error result instance
      #
      # @api public
      def self.error(message)
        new(:error, message)
      end

      # @param status [Symbol] :ok or :error
      # @param data [Object] result data or error message
      def initialize(status, data)
        @status = status.freeze
        @data = data.freeze
      end

      # @return [Boolean] true if status is :ok
      def success?
        status == :ok
      end

      # @return [Array] frozen array of [status, data]
      def to_response
        [@status.freeze, @data.freeze].freeze
      end
    end

    # Mixin for messages that query a specific account
    #
    # @api private
    module AccountQuery
      attr_reader :account_id

      # @param account_id [String] the account being queried
      def initialize(account_id:, **kwargs)
        @account_id = account_id
        super(**kwargs)
      end

      # @param auth [Array<String>] authorized account IDs
      # @return [Boolean] true if authorized for account
      def authorized?(auth)
        auth&.include?(account_id)
      end
    end

    # Message for creating new accounts
    #
    # @api public
    class CreateAccount < Message
      attr_reader :name, :initial_balance

      # @param name [String] account holder name
      # @param initial_balance [Numeric] optional starting balance
      def initialize(name:, initial_balance: 0, **kwargs)
        @name = name
        @initial_balance = initial_balance
        super(**kwargs)
      end

      # Account creation is always authorized
      #
      # @return [Boolean] true
      def authorized?(_auth)
        true
      end
    end

    # Message for transferring money between accounts
    #
    # @api public
    class Transfer < Message
      attr_reader :from_account, :to_account, :amount, :reference

      # @param from_account [String] source account ID
      # @param to_account [String] destination account ID
      # @param amount [Numeric] transfer amount
      # @param reference [String] optional reference note
      def initialize(from_account:, to_account:, amount:, reference: '', **kwargs)
        @from_account = from_account
        @to_account = to_account
        @amount = amount
        @reference = reference
        super(**kwargs)
      end

      # @param auth [Array<String>] authorized account IDs
      # @return [Boolean] true if authorized for source account
      def authorized?(auth)
        auth&.include?(from_account)
      end
    end

    # Message for querying account balance
    #
    # @api public
    class Balance < Message
      include AccountQuery
    end

    # Message for retrieving transaction history
    #
    # @api public
    class Transactions < Message
      include AccountQuery
    end

    # Message for advancing system time
    #
    # @api public
    class AdvanceTime < Message
      attr_reader :new_time

      # @param new_time [Time] time to advance to
      def initialize(new_time:, **kwargs)
        @new_time = new_time
        super(**kwargs)
      end

      # Time changes are always authorized
      #
      # @return [Boolean] true
      def authorized?(_auth)
        true
      end
    end
  end

  # BankOperator processes banking messages in a separate Ractor
  #
  # @api public
  class BankOperator
    # Starts a new bank operator in a separate Ractor
    #
    # @param name [String] bank name
    # @param simulation_time [Time] starting time
    # @param authorizations [Hash] initial auth mappings
    # @return [Ractor] the bank operator Ractor
    #
    # @api public
    def self.start(name:, simulation_time:, authorizations: {})
      Ractor.new(name, authorizations, simulation_time) do |bank_name, auths, time|
        operator = BankOperator.new(bank_name, auths, time)
        operator.run
      end
    end

    # @param name [String] bank name
    # @param authorizations [Hash] authorization mappings
    # @param simulation_time [Time] starting time
    def initialize(name, authorizations, simulation_time)
      @logger = Log.new("log/#{name.downcase.gsub(/\s+/, '_')}.log")
      @bank = DepositSystem.new(name, simulation_time, @logger)
      @message_handler = MessageHandler.new(@bank, authorizations)
    end

    # Runs the message processing loop
    #
    # @api private
    def run
      loop do
        message = Ractor.receive
        break if shutdown?(message)

        handle_message(message)
      end
    ensure
      cleanup
    end

    private

    # Handles an individual message
    #
    # @param message [Message] the message to process
    # @api private
    def handle_message(message)
      result = @message_handler.process(message)
      send_response(message, result)
    end

    # Sends response back to message sender
    #
    # @param message [Message] the original message
    # @param result [Result] the processing result
    # @api private
    def send_response(message, result)
      message.sender.send(result.to_response)
    rescue NoMethodError
      log_missing_sender(message, result)
    end

    # Logs error when sender is missing
    #
    # @param message [Message] the message with missing sender
    # @param result [Result] the processing result
    # @api private
    def log_missing_sender(message, result)
      @logger.write(@bank.current_time, "Missing sender in: #{message.inspect}")
      @logger.write(@bank.current_time, result.data)
    end

    # Checks if message is shutdown signal
    #
    # @param message [Object] the message to check
    # @return [Boolean] true if shutdown signal
    # @api private
    def shutdown?(message)
      message == :shutdown
    end

    # Performs cleanup operations
    #
    # @api private
    def cleanup
      @logger.close
    end
  end

  # Handles processing of banking messages
  #
  # @api private
  class MessageHandler
    # Maps message types to handler methods
    MESSAGE_HANDLERS = {
      Messages::CreateAccount => :handle_create_account,
      Messages::Transfer => :handle_transfer,
      Messages::Balance => :handle_balance,
      Messages::Transactions => :handle_transactions,
      Messages::AdvanceTime => :handle_advance_time
    }.freeze

    # @param bank [DepositSystem] the banking system
    # @param authorizations [Hash] authorization mappings
    def initialize(bank, authorizations)
      @bank = bank
      @authorizations = authorizations
      authorizations.default_proc = ->(hash, key) { hash[key] = [] }
    end

    # Processes an incoming message
    #
    # @param message [Message] the message to process
    # @return [Result] the processing result
    def process(message)
      auth = authorizations[message.sender]
      return Messages::Result.error('Unauthorized') unless message.authorized?(auth)

      handler_method = MESSAGE_HANDLERS[message.class]
      return Messages::Result.error('Unknown message type') unless handler_method

      send(handler_method, message)
    rescue StandardError => e
      Messages::Result.error(e.message)
    end

    private

    attr_reader :bank, :authorizations

    # @api private
    def handle_create_account(message)
      account_id = bank.create_account(name: message.name, initial_balance: message.initial_balance)
      authorizations[message.sender] << account_id
      Messages::Result.success(account_id)
    end

    # @api private
    def handle_transfer(message)
      bank.transfer(from: message.from_account, to: message.to_account, amount: message.amount,
                    reference: message.reference)
      Messages::Result.success(true)
    end

    # @api private
    def handle_balance(message)
      Messages::Result.success(bank.balance(message.account_id))
    end

    # @api private
    def handle_transactions(message)
      Messages::Result.success(bank.transactions(message.account_id))
    end

    # @api private
    def handle_advance_time(message)
      bank.advance_time(message.new_time)
      Messages::Result.success(bank.current_time)
    end
  end

  private_constant :MessageHandler
end
