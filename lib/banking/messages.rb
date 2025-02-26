# frozen_string_literal: true

module Banking
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

    # Message for registering the institutional directory
    #
    # @api public
    class InstitutionsDirectory
      attr_reader :directory

      # @param directory [Hash] Hash of running Ractors
      def initialize(directory:)
        @directory = directory
        Ractor.make_shareable(self)
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

    # Message for creating new mirror accounts
    #
    # @api public
    class CreateMirrorAccount < CreateAccount
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
end
