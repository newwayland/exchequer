# frozen_string_literal: true

require 'account'
require 'rspec'
require 'time'

describe Account::Transaction do
  let(:valid_timestamp) { Time.now }

  it 'creates a valid transaction' do
    transaction = described_class.new(timestamp: valid_timestamp, amount: 100, type: :credit)
    expect(transaction.amount).to eq(100)
    expect(transaction.type).to eq(:credit)
  end

  it 'raises an error for a negative amount' do
    expect do
      described_class.new(timestamp: valid_timestamp, amount: -50, type: :debit)
    end.to raise_error(Account::Error, 'Amount must be positive')
  end

  it 'raises an error for a zero amount' do
    expect do
      described_class.new(timestamp: valid_timestamp, amount: 0, type: :credit)
    end.to raise_error(Account::Error, 'Amount must be positive')
  end

  it 'raises an error for an invalid transaction type' do
    expect do
      described_class.new(timestamp: valid_timestamp, amount: 50, type: :refund)
    end.to raise_error(Account::Error, 'Invalid transaction type')
  end

  it 'handles very large transaction amounts' do
    trillion = 1_000_000_000_000
    transaction = described_class.new(timestamp: valid_timestamp, amount: trillion, type: :credit)
    expect(transaction.amount).to eq(trillion)
  end
end

describe Account::CreditNormal do
  let(:credit_account) { described_class.new('Business Credit', 1_000_000) }
  let(:time) { Time.now }

  it 'initializes with correct attributes' do
    expect(credit_account.name).to eq('Business Credit')
    expect(credit_account.balance).to eq(1_000_000)
    expect(credit_account.transactions).to be_empty
  end

  it 'increases balance with credit' do
    credit_account.credit(time, 500_000)
    expect(credit_account.balance).to eq(1_500_000)
  end

  it 'decreases balance with debit' do
    credit_account.debit(time, 200_000)
    expect(credit_account.balance).to eq(800_000)
  end

  it 'handles very large credit amounts' do
    trillion = 1_000_000_000_000
    credit_account.credit(time, trillion)
    expect(credit_account.balance).to eq(1_000_001_000_000) # 1M + 1T
  end

  it 'handles very large debit amounts' do
    trillion = 1_000_000_000_000
    credit_account.debit(time, trillion)
    expect(credit_account.balance).to eq(-999_999_000_000) # 1M - 1T
  end

  it 'rejects zero credit transactions' do
    expect { credit_account.credit(time, 0) }.to raise_error(Account::Error, 'Amount must be positive')
  end

  it 'rejects zero debit transactions' do
    expect { credit_account.debit(time, 0) }.to raise_error(Account::Error, 'Amount must be positive')
  end
end

describe Account::DebitNormal do
  let(:debit_account) { described_class.new('Personal Debit', 500_000) }
  let(:time) { Time.now }

  it 'initializes with correct attributes' do
    expect(debit_account.name).to eq('Personal Debit')
    expect(debit_account.balance).to eq(500_000)
    expect(debit_account.transactions).to be_empty
  end

  it 'increases balance with debit' do
    debit_account.debit(time, 250_000)
    expect(debit_account.balance).to eq(750_000)
  end

  it 'decreases balance with credit' do
    debit_account.credit(time, 150_000)
    expect(debit_account.balance).to eq(350_000)
  end

  it 'handles very large debit amounts' do
    trillion = 1_000_000_000_000
    debit_account.debit(time, trillion)
    expect(debit_account.balance).to eq(1_000_000_500_000) # 500K + 1T
  end

  it 'handles very large credit amounts' do
    trillion = 1_000_000_000_000
    debit_account.credit(time, trillion)
    expect(debit_account.balance).to eq(-999_999_500_000) # 500K - 1T
  end

  it 'rejects zero debit transactions' do
    expect { debit_account.debit(time, 0) }.to raise_error(Account::Error, 'Amount must be positive')
  end

  it 'rejects zero credit transactions' do
    expect { debit_account.credit(time, 0) }.to raise_error(Account::Error, 'Amount must be positive')
  end
end

