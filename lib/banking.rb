# frozen_string_literal: true

require 'securerandom'
require_relative 'account'
require_relative 'log'

# Banking module provides functionality for managing bank accounts,
# handling transactions, and authorizing access to accounts.
module Banking
  # Error raised when an invalid account is accessed.
  class InvalidAccount < StandardError; end

  # DepositSystem manages bank accounts, transactions, and maintains system time.
  class DepositSystem
    attr_reader :name, :accounts, :current_time

    # Initializes a DepositSystem instance.
    #
    # @param name [String] The name of the bank.
    # @param simulation_time [Time] The current simulated time.
    def initialize(name, simulation_time, logger)
      @name = name
      @current_time = simulation_time
      @logger = logger

      # Default proc raises an error if an invalid account ID is accessed.
      @accounts = Hash.new { |_, key| raise InvalidAccount, "Account Number not found: #{key}" }
    end

    # Advances the system time.
    #
    # @param new_time [Time] The new time to advance to.
    # @raise [ArgumentError] If new_time is nil or earlier than the current time.
    def advance_time(new_time)
      raise ArgumentError, 'New time must be provided' if new_time.nil?
      raise ArgumentError, 'Time cannot move backwards' if new_time < @current_time

      @current_time = new_time
      log_event("Clock advanced to #{@current_time}")
    end

    # Creates a new account.
    #
    # @param name [String] The account holder's name.
    # @param initial_balance [Numeric] The starting balance of the account.
    # @return [String] The account ID.
    # @raise [ArgumentError] If the account name is blank.
    def create_account(name:, initial_balance: 0)
      raise ArgumentError, 'Account name cannot be blank' if name.to_s == ''

      account = Account::CreditNormal.new(name)
      @accounts[account.id] = account
      credit_initial_balance(account, initial_balance)
      log_event("Account created: #{account.id} - #{name}")
      account.id
    end

    # Transfers money between accounts.
    #
    # @param from [String] The source account ID.
    # @param to [String] The destination account ID.
    # @param amount [Numeric] The transfer amount.
    # @param reference [String] A reference note for the transfer.
    # @return [Boolean] True if the transfer is successful.
    # @raise [ArgumentError] If the source and destination are the same.
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

    # Retrieves the balance of an account.
    #
    # @param account_id [String] The account ID.
    # @return [Numeric] The account balance.
    def balance(account_id)
      @accounts[account_id].balance
    end

    # Retrieves the transactions of an account.
    #
    # @param account_id [String] The account ID.
    # @return [Array<Transaction>] The list of transactions.
    def transactions(account_id)
      @accounts[account_id].transactions
    end

    # Retrieves the name associated with an account.
    #
    # @param account_id [String] The account ID.
    # @return [String] The account holder's name.
    def account_name(account_id)
      @accounts[account_id].name
    end

    private

    # Handles the debit operation for the source account during a transfer.
    #
    # @param source [Account] The source account.
    # @param destination_name [String] The name of the destination account.
    # @param amount [Numeric] The transfer amount.
    # @param reference [String] A reference note for the transfer.
    def source_transfer(source, destination_name, amount, reference)
      description = "Transfer to #{destination_name} - #{reference}"
      source.debit(@current_time, amount, description)
    end

    # Handles the credit operation for the destination account during a transfer.
    #
    # @param destination [Account] The destination account.
    # @param source_name [String] The name of the source account.
    # @param amount [Numeric] The transfer amount.
    # @param reference [String] A reference note for the transfer.
    def destination_transfer(destination, source_name, amount, reference)
      description = "Bank credit from #{source_name} - #{reference}"
      destination.credit(@current_time, amount, description)
    end

    # Credits an initial balance when an account is created.
    #
    # @param destination [Account] The new account.
    # @param amount [Numeric] The initial balance amount.
    def credit_initial_balance(destination, amount)
      if amount.positive?
        destination.credit(@current_time, amount, 'Initial balance')
      elsif amount.negative?
        destination.debit(@current_time, -amount, 'Initial balance')
      end
    end

    # Logs an event with a timestamp.
    #
    # @param message [String] The event message to log.
    def log_event(message)
      @logger.write(@current_time, message)
    end
  end

  module Messages
    class Message
      attr_reader :sender

      def initialize(sender:)
        @sender = sender
        Ractor.make_shareable(self)
      end

      def authorized?(_auth)
        raise NotImplementedError, 'Subclasses must implement `authorized?`'
      end
    end

    class Result
      attr_reader :status, :data

      def self.success(data)
        new(:ok, data)
      end

      def self.error(message)
        new(:error, message)
      end

      def initialize(status, data)
        @status = status.freeze
        @data = data.freeze
      end

      def success?
        status == :ok
      end

      def to_response
        [@status.freeze, @data.freeze].freeze
      end
    end

    module AccountQuery
      attr_reader :account_id

      def initialize(account_id:, **kwargs)
        @account_id = account_id
        super(**kwargs)
      end

      def authorized?(auth)
        auth&.include?(account_id)
      end
    end

    class CreateAccount < Message
      attr_reader :name, :initial_balance

      def initialize(name:, initial_balance: 0, **kwargs)
        @name = name
        @initial_balance = initial_balance
        super(**kwargs)
      end

      def authorized?(_auth)
        true
      end
    end

    class Transfer < Message
      attr_reader :from_account, :to_account, :amount, :reference

      def initialize(from_account:, to_account:, amount:, reference: '', **kwargs)
        @from_account = from_account
        @to_account = to_account
        @amount = amount
        @reference = reference
        super(**kwargs)
      end

      def authorized?(auth)
        auth&.include?(from_account)
      end
    end

    class Balance < Message
      include AccountQuery
    end

    class Transactions < Message
      include AccountQuery
    end

    class AdvanceTime < Message
      attr_reader :new_time

      def initialize(new_time:, **kwargs)
        @new_time = new_time
        super(**kwargs)
      end

      def authorized?(_auth)
        true
      end
    end
  end

  class BankOperator
    def self.start(name:, simulation_time:, authorizations: {})
      Ractor.new(name, authorizations, simulation_time) do |bank_name, auths, time|
        operator = BankOperator.new(bank_name, auths, time)
        operator.run
      end
    end

    def initialize(name, authorizations, simulation_time)
      @logger = Log.new("log/#{name.downcase.gsub(/\s+/, '_')}.log")
      @bank = DepositSystem.new(name, simulation_time, @logger)
      @message_handler = MessageHandler.new(@bank, authorizations)
    end

    def run
      loop do
        message = Ractor.receive
        break if message == :shutdown

        result = @message_handler.process(message)
        begin
          message.sender.send(result.to_response)
        rescue NoMethodError
          @logger.write(@bank.current_time, "Missing sender in: #{message.inspect}")
          @logger.write(@bank.current_time, result.data)
        end
      end
    ensure
      @logger.close
    end
  end

  class MessageHandler
    MESSAGE_HANDLERS = {
      Messages::CreateAccount => :handle_create_account,
      Messages::Transfer => :handle_transfer,
      Messages::Balance => :handle_balance,
      Messages::Transactions => :handle_transactions,
      Messages::AdvanceTime => :handle_advance_time
    }.freeze

    def initialize(bank, authorizations)
      @bank = bank
      @authorizations = authorizations
      authorizations.default_proc = ->(hash, key) { hash[key] = [] }
    end

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

    def handle_create_account(message)
      account_id = bank.create_account(name: message.name, initial_balance: message.initial_balance)
      authorizations[message.sender] << account_id
      Messages::Result.success(account_id)
    end

    def handle_transfer(message)
      bank.transfer(from: message.from_account, to: message.to_account, amount: message.amount,
                    reference: message.reference)
      Messages::Result.success(true)
    end

    def handle_balance(message)
      Messages::Result.success(bank.balance(message.account_id))
    end

    def handle_transactions(message)
      Messages::Result.success(bank.transactions(message.account_id))
    end

    def handle_advance_time(message)
      bank.advance_time(message.new_time)
      Messages::Result.success(bank.current_time)
    end
  end

  private_constant :MessageHandler
end
