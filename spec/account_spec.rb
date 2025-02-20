# frozen_string_literal: true

require 'account'
require 'rspec'
require 'time'

describe Account::Transaction do
  let(:valid_timestamp) { Time.now }
  let(:valid_description) { 'Payment for services' }

  it 'creates a valid transaction with a description' do
    transaction = described_class.new(
      timestamp: valid_timestamp,
      amount: 100,
      type: :credit,
      description: valid_description
    )
    expect(transaction.amount).to eq(100)
    expect(transaction.type).to eq(:credit)
    expect(transaction.description).to eq(valid_description)
  end

  it 'allows transactions with an empty description' do
    transaction = described_class.new(
      timestamp: valid_timestamp,
      amount: 100,
      type: :credit,
      description: ''
    )
    expect(transaction.description).to eq('')
  end

  it 'allows transactions with a nil description' do
    transaction = described_class.new(
      timestamp: valid_timestamp,
      amount: 100,
      type: :credit,
      description: nil
    )
    expect(transaction.description).to be_nil
  end

  it 'raises an error for a negative amount' do
    expect do
      described_class.new(timestamp: valid_timestamp, amount: -50, type: :debit, description: valid_description)
    end.to raise_error(ArgumentError, 'Amount must be positive')
  end

  it 'raises an error for a zero amount' do
    expect do
      described_class.new(timestamp: valid_timestamp, amount: 0, type: :credit, description: valid_description)
    end.to raise_error(ArgumentError, 'Amount must be positive')
  end

  it 'raises an error for an invalid transaction type' do
    expect do
      described_class.new(timestamp: valid_timestamp, amount: 50, type: :refund, description: valid_description)
    end.to raise_error(ArgumentError, 'Invalid transaction type: refund')
  end

  it 'handles very large transaction amounts' do
    trillion = 1_000_000_000_000
    transaction = described_class.new(timestamp: valid_timestamp, amount: trillion, type: :credit,
                                      description: valid_description)
    expect(transaction.amount).to eq(trillion)
  end
end

describe Account::CreditNormal do
  let(:credit_account) { described_class.new('Business Credit') }
  let(:time) { Time.now }

  it 'initializes with correct attributes' do
    expect(credit_account.name).to eq('Business Credit')
    expect(credit_account.balance).to eq(0)
    expect(credit_account.transactions).to be_empty
  end

  it 'increases balance with credit' do
    credit_account.credit(time, 500_000)
    expect(credit_account.balance).to eq(500_000)
  end

  it 'decreases balance with debit' do
    credit_account.debit(time, 200_000)
    expect(credit_account.balance).to eq(-200_000)
  end

  it 'handles very large credit amounts' do
    trillion = 1_000_000_000_000
    credit_account.credit(time, 1_000_000)
    credit_account.credit(time, trillion)
    expect(credit_account.balance).to eq(1_000_001_000_000) # 1M + 1T
  end

  it 'handles very large debit amounts' do
    trillion = 1_000_000_000_000
    credit_account.credit(time, 1_000_000)
    credit_account.debit(time, trillion)
    expect(credit_account.balance).to eq(-999_999_000_000) # 1M - 1T
  end

  it 'rejects zero credit transactions' do
    expect { credit_account.credit(time, 0) }.to raise_error(ArgumentError, 'Amount must be positive')
  end

  it 'rejects zero debit transactions' do
    expect { credit_account.debit(time, 0) }.to raise_error(ArgumentError, 'Amount must be positive')
  end
end

describe Account::DebitNormal do
  let(:debit_account) { described_class.new('Personal Debit') }
  let(:time) { Time.now }

  it 'initializes with correct attributes' do
    expect(debit_account.name).to eq('Personal Debit')
    expect(debit_account.balance).to eq(0)
    expect(debit_account.transactions).to be_empty
  end

  it 'increases balance with debit' do
    debit_account.debit(time, 250_000)
    expect(debit_account.balance).to eq(250_000)
  end

  it 'decreases balance with credit' do
    debit_account.credit(time, 150_000)
    expect(debit_account.balance).to eq(-150_000)
  end

  it 'handles very large debit amounts' do
    trillion = 1_000_000_000_000
    debit_account.debit(time, 500_000)
    debit_account.debit(time, trillion)
    expect(debit_account.balance).to eq(1_000_000_500_000) # 500K + 1T
  end

  it 'handles very large credit amounts' do
    trillion = 1_000_000_000_000
    debit_account.debit(time, 500_000)
    debit_account.credit(time, trillion)
    expect(debit_account.balance).to eq(-999_999_500_000) # 500K - 1T
  end

  it 'rejects zero debit transactions' do
    expect { debit_account.debit(time, 0) }.to raise_error(ArgumentError, 'Amount must be positive')
  end

  it 'rejects zero credit transactions' do
    expect { debit_account.credit(time, 0) }.to raise_error(ArgumentError, 'Amount must be positive')
  end
end
