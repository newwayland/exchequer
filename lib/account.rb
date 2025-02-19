# frozen_string_literal: true

require 'forwardable'

# The Account module encapsulates different types of financial accounts
# and transaction handling.
module Account
  TRANSACTION_TYPE = %i[debit credit].freeze

  # Custom error class for handling invalid transactions.
  Error = Class.new(StandardError)

  # Represents a financial transaction.
  Transaction = Struct.new(:timestamp, :type, :description, :amount, keyword_init: true) do
    def initialize(*)
      super
      validate!
    end

    private

    def validate!
      raise Error, 'Amount must be positive' unless amount.positive?
      raise Error, 'Invalid transaction type' unless TRANSACTION_TYPE.include?(type)
    end
  end

  # Dynamically creates CreditNormal and DebitNormal account classes.
  TRANSACTION_TYPE.each do |typ|
    klass_name = "#{typ.capitalize}Normal"
    const_set(
      klass_name,
      Class.new do
        extend Forwardable
        def_delegators :@account, :name, :balance, :transactions, *TRANSACTION_TYPE
        def_delegator :@account, :object_id, :id

        define_method(:initialize) do |name, initial_balance = 0|
          @account = Base.new(name, initial_balance, increasing_type: typ.downcase.to_sym)
        end
      end
    )
  end

  # Base account class that maintains balance and transaction history.
  class Base
    attr_reader :name, :balance, :transactions

    # Initializes an account with a name, balance, and increasing transaction type.
    #
    # @param name [String] The account name.
    # @param initial_balance [Numeric] The starting balance.
    # @param increasing_type [Symbol] The transaction type that increases the balance (:credit or :debit).
    def initialize(name, initial_balance = 0, increasing_type:)
      @name = name
      @balance = initial_balance
      @transactions = []
      @increasing_type = increasing_type
    end

    # Dynamically defines credit and debit methods.
    TRANSACTION_TYPE.each do |typ|
      define_method(typ) do |time, amt, desc = nil|
        apply_transaction(Transaction.new(timestamp: time, amount: amt, type: typ, description: desc))
      end
    end

    private

    # Applies a transaction to the account.
    #
    # @param transaction [Transaction] The transaction to be applied.
    # @return [Numeric] The updated balance.
    def apply_transaction(transaction)
      @balance += calculate_adjustment(transaction)
      @transactions << transaction
      @balance
    end

    # Calculates the balance adjustment based on transaction type.
    #
    # @param transaction [Transaction] The transaction to calculate.
    # @return [Numeric] The adjustment amount.
    def calculate_adjustment(transaction)
      transaction.type == @increasing_type ? transaction.amount : -transaction.amount
    end
  end

  private_constant :Base
end
