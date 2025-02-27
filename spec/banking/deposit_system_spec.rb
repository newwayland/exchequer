# frozen_string_literal: true

require 'banking'
require 'time'

RSpec.shared_examples 'an invalid account error' do
  it 'raises an error with a descriptive message' do
    expect { subject }
      .to raise_error(Banking::InvalidAccount, 'Account Number not found: invalid')
  end
end

describe Banking::DepositSystem do
  let(:fake_logger) { instance_double(Log, :<< => nil, close: nil) }
  let(:initial_time) { Time.new(2024, 1, 1, 9, 0) }
  let(:bank) { described_class.new('Test Bank', initial_time, fake_logger) }

  describe '#create_account' do
    context 'when creating an account with an initial balance' do
      let(:account_id) { bank.create_account(name: 'Test Account', initial_balance: 1000) }

      it 'creates an account successfully' do
        expect(bank.balance(account_id)).to eq(1000)
      end

      it 'sets the correct account name' do
        expect(bank.account_name(account_id)).to eq('Test Account')
      end

      it 'creates an initial balance transaction' do
        transactions = bank.transactions(account_id)
        expect(transactions.size).to eq(1)
        expect(transactions.first.to_h).to include(
          timestamp: initial_time,
          type: :credit,
          amount: 1000,
          description: 'Initial balance'
        )
      end
    end

    context 'when creating an account with zero initial balance' do
      let(:account_id) { bank.create_account(name: 'Zero Account') }

      it 'defaults to a zero balance' do
        expect(bank.balance(account_id)).to eq(0)
      end

      it 'creates no initial transaction' do
        expect(bank.transactions(account_id)).to be_empty
      end
    end

    context 'when creating an account with a negative balance' do
      let(:account_id) { bank.create_account(name: 'Test Account', initial_balance: -1000) }

      it 'creates an initial balance transaction' do
        transactions = bank.transactions(account_id)
        expect(transactions.size).to eq(1)
        expect(transactions.first.to_h).to include(
          timestamp: initial_time,
          type: :debit,
          amount: 1000,
          description: 'Initial balance'
        )
      end
    end

    context 'with invalid inputs' do
      it 'raises error for blank name' do
        expect { bank.create_account(name: '') }
          .to raise_error(ArgumentError, 'Account name cannot be blank')
      end
    end
  end

  describe '#create_mirror_account' do
    context 'when creating an account with an initial balance' do
      let(:account_id) { bank.create_mirror_account(name: 'Test Account', initial_balance: 1000) }

      it 'creates an account successfully' do
        expect(bank.balance(account_id)).to eq(1000)
      end

      it 'sets the correct account name' do
        expect(bank.account_name(account_id)).to eq('Test Account (M)')
      end

      it 'creates an initial balance transaction' do
        transactions = bank.transactions(account_id)
        expect(transactions.size).to eq(1)
        expect(transactions.first.to_h).to include(
          timestamp: initial_time,
          type: :debit,
          amount: 1000,
          description: 'Initial balance'
        )
      end
    end

    context 'when creating an account with zero initial balance' do
      let(:account_id) { bank.create_mirror_account(name: 'Zero Account') }

      it 'defaults to a zero balance' do
        expect(bank.balance(account_id)).to eq(0)
      end

      it 'creates no initial transaction' do
        expect(bank.transactions(account_id)).to be_empty
      end
    end

    context 'when creating an account with a negative balance' do
      let(:account_id) { bank.create_mirror_account(name: 'Test Account', initial_balance: -1000) }

      it 'creates an initial balance transaction' do
        transactions = bank.transactions(account_id)
        expect(transactions.size).to eq(1)
        expect(transactions.first.to_h).to include(
          timestamp: initial_time,
          type: :credit,
          amount: 1000,
          description: 'Initial balance'
        )
      end
    end

    context 'with invalid inputs' do
      it 'raises error for blank name' do
        expect { bank.create_mirror_account(name: '') }
          .to raise_error(ArgumentError, 'Account name cannot be blank')
      end
    end
  end

  describe '#transfer' do
    let(:source_id) { bank.create_account(name: 'Source Account', initial_balance: 1000) }
    let(:dest_id) { bank.create_account(name: 'Destination Account', initial_balance: 0) }

    context 'when transfer is successful' do
      before do
        bank.transfer(from: source_id, to: dest_id, amount: 500, reference: 'Test transfer')
      end

      it 'debits the correct amount from the source account' do
        expect(bank.balance(source_id)).to eq(500)
      end

      it 'credits the correct amount to the destination account' do
        expect(bank.balance(dest_id)).to eq(500)
      end

      it 'creates matching transactions in both accounts' do
        source_trans = bank.transactions(source_id).last
        dest_trans = bank.transactions(dest_id).last

        expect(source_trans.to_h).to include(
          timestamp: initial_time,
          type: :debit,
          amount: 500,
          description: 'Transfer to Destination Account - Test transfer'
        )

        expect(dest_trans.to_h).to include(
          timestamp: initial_time,
          type: :credit,
          amount: 500,
          description: 'Bank credit from Source Account - Test transfer'
        )
      end
    end

    context 'when transfer exceeds balance' do
      before do
        bank.transfer(from: source_id, to: dest_id, amount: 2000, reference: 'Big Transfer')
      end

      it 'allows the source account to go negative' do
        expect(bank.balance(source_id)).to eq(-1000)
      end

      it 'credits the full transfer amount to the destination' do
        expect(bank.balance(dest_id)).to eq(2000)
      end
    end

    context 'with invalid inputs' do
      it 'raises error for zero amount' do
        expect { bank.transfer(from: source_id, to: dest_id, amount: 0, reference: 'Zero') }
          .to raise_error(ArgumentError, 'Amount must be positive')
      end

      it 'raises error for negative amount' do
        expect { bank.transfer(from: source_id, to: dest_id, amount: -100, reference: 'Negative') }
          .to raise_error(ArgumentError, 'Amount must be positive')
      end

      it 'accepts blank reference' do
        expect { bank.transfer(from: source_id, to: dest_id, amount: 100, reference: '') }
          .not_to raise_error
      end

      it 'accepts no reference' do
        expect { bank.transfer(from: source_id, to: dest_id, amount: 100) }
          .not_to raise_error
      end

      it 'raises error for same source and destination' do
        expect { bank.transfer(from: source_id, to: source_id, amount: 100, reference: 'Self') }
          .to raise_error(ArgumentError, 'Source and destination accounts cannot be the same')
      end
    end

    context 'when source account does not exist' do
      subject { bank.transfer(from: 'invalid', to: dest_id, amount: 100, reference: 'Invalid source') }

      include_examples 'an invalid account error', :transfer
    end

    context 'when destination account does not exist' do
      subject { bank.transfer(from: source_id, to: 'invalid', amount: 100, reference: 'Invalid destination') }

      include_examples 'an invalid account error', :transfer
    end
  end

  describe '#balance' do
    let(:valid_account) { bank.create_account(name: 'Valid Account', initial_balance: 500) }

    it 'returns the correct balance for a valid account' do
      expect(bank.balance(valid_account)).to eq(500)
    end

    context 'with invalid account' do
      subject { bank.balance('invalid') }

      include_examples 'an invalid account error', :balance
    end
  end

  describe '#transactions' do
    let(:valid_account) { bank.create_account(name: 'Transaction Account', initial_balance: 100) }

    it 'returns transactions in chronological order' do
      bank.transfer(from: valid_account, to: bank.create_account(name: 'Other'), amount: 50, reference: 'First')
      bank.advance_time(initial_time + 3600)
      bank.transfer(from: valid_account, to: bank.create_account(name: 'Another'), amount: 30, reference: 'Second')

      transactions = bank.transactions(valid_account)
      expect(transactions.map(&:description))
        .to eq(['Initial balance', 'Transfer to Other - First', 'Transfer to Another - Second'])
    end

    context 'with invalid account' do
      subject { bank.transactions('invalid') }

      include_examples 'an invalid account error', :transactions
    end
  end

  describe '#advance_time' do
    it 'updates the simulation time correctly' do
      new_time = initial_time + 3600
      bank.advance_time(new_time)
      expect(bank.current_time).to eq(new_time)
    end

    context 'with invalid times' do
      it 'raises error when moving time backwards' do
        expect { bank.advance_time(initial_time - 3600) }
          .to raise_error(ArgumentError, 'Time cannot move backwards')
      end

      it 'raises error for nil time' do
        expect { bank.advance_time(nil) }
          .to raise_error(ArgumentError, 'New time must be provided')
      end
    end
  end
end
