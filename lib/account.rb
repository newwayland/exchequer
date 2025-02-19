# frozen_string_literal: true

require 'forwardable'

module Account
  TRANSACTION_TYPE = %i[debit credit].freeze
  Error = Class.new(StandardError)

  Transaction = Struct.new(:timestamp, :amount, :type, keyword_init: true) do
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

  # Create CreditNormal and DebitNormal classes
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

  class Base
    attr_reader :name, :balance, :transactions

    def initialize(name, initial_balance = 0, increasing_type:)
      @name = name
      @balance = initial_balance
      @transactions = []
      @increasing_type = increasing_type
    end

    # Create credit and debit methods
    TRANSACTION_TYPE.each do |typ|
      define_method(typ) do |time, amt|
        apply_transaction(Transaction.new(timestamp: time, amount: amt, type: typ))
      end
    end

    private

    def apply_transaction(transaction)
      @balance += calculate_adjustment(transaction)
      @transactions << transaction
      @balance
    end

    def calculate_adjustment(transaction)
      transaction.type == @increasing_type ? transaction.amount : -transaction.amount
    end
  end

  private_constant :Base
end
