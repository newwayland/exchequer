# frozen_string_literal: true

# The Account module encapsulates different types of financial accounts
# and transaction handling.
module Account
  TRANSACTION_TYPE = %i[debit credit].freeze

  # Represents a financial transaction.
  Transaction = Struct.new(:timestamp, :type, :description, :amount, keyword_init: true) do
    def initialize(...)
      super(...)
      validate!
      freeze
    end

    private

    def validate!
      raise ArgumentError, 'Amount must be positive' unless amount.positive?
      raise ArgumentError, "Invalid transaction type: #{type}" unless TRANSACTION_TYPE.include?(type)
    end
  end

  class CreditNormal
    attr_reader :name, :balance, :transactions

    # Initializes an account with a name, balance, and increasing transaction type.
    #
    # @param name [String] The account name.
    def initialize(name)
      @name = name
      @balance = 0
      @transactions = []
    end

    def id
      object_id
    end

    def credit(time, amt, desc = nil)
      @transactions << Transaction.new(timestamp: time, amount: amt, type: :credit, description: desc)
      @balance += amt
    end

    def debit(time, amt, desc = nil)
      @transactions << Transaction.new(timestamp: time, amount: amt, type: :debit, description: desc)
      @balance -= amt
    end
  end

  class DebitNormal
    attr_reader :name, :balance, :transactions

    # Initializes an account with a name, balance, and increasing transaction type.
    #
    # @param name [String] The account name.
    def initialize(name)
      @name = name
      @balance = 0
      @transactions = []
    end

    def id
      object_id
    end

    def credit(time, amt, desc = nil)
      @transactions << Transaction.new(timestamp: time, amount: amt, type: :credit, description: desc)
      @balance -= amt
    end

    def debit(time, amt, desc = nil)
      @transactions << Transaction.new(timestamp: time, amount: amt, type: :debit, description: desc)
      @balance += amt
    end
  end
end
