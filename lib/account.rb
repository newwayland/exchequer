# frozen_string_literal: true

require 'forwardable'

# The Account module encapsulates different types of financial accounts
# and transaction handling.
module Account
  TRANSACTION_TYPE = %i[debit credit].freeze

  # Represents a financial transaction.
  Transaction = Struct.new(:timestamp, :type, :description, :amount, keyword_init: true) do
    def initialize(*)
      super
      validate!
    end

    private

    def validate!
      raise ArgumentError, 'Amount must be positive' unless amount.positive?
      raise ArgumentError, "Invalid transaction type: #{type}" unless TRANSACTION_TYPE.include?(type)
    end
  end

  class CreditNormal
    extend Forwardable
    def_delegators :@account, :name, :balance, :transactions, *TRANSACTION_TYPE
    def_delegator :@account, :object_id, :id

    def initialize(name)
      @account = Base.new(name, increasing_type: :credit)
    end
  end

  class DebitNormal
    extend Forwardable
    def_delegators :@account, :name, :balance, :transactions, *TRANSACTION_TYPE
    def_delegator :@account, :object_id, :id

    def initialize(name)
      @account = Base.new(name, increasing_type: :debit)
    end
  end

  # Base account class that maintains balance and transaction history.
  class Base
    attr_reader :name, :balance, :transactions

    # Initializes an account with a name, balance, and increasing transaction type.
    #
    # @param name [String] The account name.
    # @param increasing_type [Symbol] The transaction type that increases the balance (:credit or :debit).
    def initialize(name, increasing_type:)
      @name = name
      @balance = 0
      @transactions = []
      @increasing_type = increasing_type
    end

    def credit(time, amt, desc = nil)
      apply_transaction(Transaction.new(timestamp: time, amount: amt, type: :credit, description: desc))
    end

    def debit(time, amt, desc = nil)
      apply_transaction(Transaction.new(timestamp: time, amount: amt, type: :debit, description: desc))
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
