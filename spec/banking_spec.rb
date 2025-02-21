# frozen_string_literal: true

require 'banking'
require 'time'

RSpec.shared_examples 'an invalid account error' do
  it 'raises an error with a descriptive message' do
    expect { subject }
      .to raise_error(Banking::InvalidAccount, 'Account Number not found: invalid')
  end
end

describe Banking do
  let(:fake_logger) { instance_double(Log, write: nil) }

  describe Banking::DepositSystem do
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

  describe Banking::Messages do
    let(:sender) { 1 }
    let(:auth) { [sender] }
    let(:noauth) { [] }

    describe Banking::Messages::Result do
      it 'creates a successful result' do
        result = described_class.success('data')
        expect(result.success?).to be true
        expect(result.to_response).to eq([:ok, 'data'])
        expect(Ractor).to be_shareable(result.to_response)
      end

      it 'creates an error result' do
        result = described_class.error('Error message')
        expect(result.success?).to be false
        expect(result.to_response).to eq([:error, 'Error message'])
        expect(Ractor).to be_shareable(result.to_response)
      end
    end

    describe Banking::Messages::CreateAccount do
      let(:message) { described_class.new(sender: sender, name: 'John Doe', initial_balance: 100) }

      it 'is Ractor shareable' do
        expect(Ractor).to be_shareable(message)
      end

      it 'is always authorized' do
        expect(message.authorized?(auth)).to be true
      end
    end

    describe Banking::Messages::Transfer do
      let(:message) do
        described_class.new(sender: sender, from_account: 1, to_account: 2, amount: 50, reference: 'Test')
      end

      it 'is Ractor shareable' do
        expect(Ractor).to be_shareable(message)
      end

      it 'is authorized if the user has access to the source account' do
        expect(message.authorized?(auth)).to be true
      end

      it 'is not authorized if the user lacks access to the source account' do
        expect(message.authorized?(noauth)).to be false
      end
    end

    describe Banking::Messages::Balance do
      let(:message) { described_class.new(sender: sender, account_id: 1) }

      it 'is Ractor shareable' do
        expect(Ractor).to be_shareable(message)
      end

      it 'is authorized if the user has access to the account' do
        expect(message.authorized?(auth)).to be true
      end

      it 'is not authorized if the user lacks access to the account' do
        expect(message.authorized?(noauth)).to be false
      end
    end

    describe Banking::Messages::Transactions do
      let(:message) { described_class.new(sender: sender, account_id: 1) }

      it 'is Ractor shareable' do
        expect(Ractor).to be_shareable(message)
      end

      it 'is authorized if the user has access to the account' do
        expect(message.authorized?(auth)).to be true
      end

      it 'is not authorized if the user lacks access to the account' do
        expect(message.authorized?(noauth)).to be false
      end
    end

    describe Banking::Messages::AdvanceTime do
      let(:message) { described_class.new(sender: sender, new_time: Time.now) }

      it 'is Ractor shareable' do
        expect(Ractor).to be_shareable(message)
      end

      it 'is always authorized' do
        expect(message.authorized?(auth)).to be true
      end
    end
  end

  describe Banking::BankOperator do
    let(:simulation_time) { Time.parse('2024-02-21 10:00:00 UTC') }

    let(:operator) do
      described_class.start(
        name: 'Test Bank',
        simulation_time: simulation_time
      )
    end

    let(:client) do
      Ractor.new(name: 'client') do
        loop do
          msg = receive
          break if msg == :close

          Ractor.yield msg
        end
      end
    end

    # Drain the Ractors of all remaining messages
    after do
      begin
        client.send(:close)
        loop do
          client.take
        end
      rescue Ractor::ClosedError
        # Client closed
      end
      begin
        operator.send(:shutdown)
        loop do
          operator.take
        end
      rescue Ractor::ClosedError
        # Operator closed
      end
    end

    describe 'account creation' do
      it 'successfully creates an account with initial balance' do
        message = Banking::Messages::CreateAccount.new(
          sender: client,
          name: 'John Doe',
          initial_balance: 1000
        )

        operator.send(message)
        status, account_id = client.take

        expect(status).to eq(:ok)
        expect(account_id).to be_a(Integer)
      end

      it 'fails to create account with blank name' do
        message = Banking::Messages::CreateAccount.new(
          sender: client,
          name: '',
          initial_balance: 1000
        )

        operator.send(message)
        status, error = client.take

        expect(status).to eq(:error)
        expect(error).to eq('Account name cannot be blank')
      end
    end

    describe 'money transfers' do
      let(:source_account) do
        message = Banking::Messages::CreateAccount.new(
          sender: client,
          name: 'Source Account',
          initial_balance: 1000
        )
        operator.send(message)
        _, account_id = client.take
        account_id
      end

      let(:destination_account) do
        message = Banking::Messages::CreateAccount.new(
          sender: client,
          name: 'Destination Account',
          initial_balance: 0
        )
        operator.send(message)
        _, account_id = client.take
        account_id
      end

      it 'successfully transfers money between accounts' do
        transfer_message = Banking::Messages::Transfer.new(
          sender: client,
          from_account: source_account,
          to_account: destination_account,
          amount: 500,
          reference: 'Test transfer'
        )

        operator.send(transfer_message)
        status, result = client.take

        expect(status).to eq(:ok)
        expect(result).to be true

        # Verify source account balance
        balance_message = Banking::Messages::Balance.new(
          sender: client,
          account_id: source_account
        )

        operator.send(balance_message)
        status, balance = client.take

        expect(status).to eq(:ok)
        expect(balance).to eq(500)

        # Verify destination account balance
        balance_message = Banking::Messages::Balance.new(
          sender: client,
          account_id: destination_account
        )

        operator.send(balance_message)
        status, balance = client.take

        expect(status).to eq(:ok)
        expect(balance).to eq(500)
      end

      it 'prevents transfer between same accounts' do
        transfer_message = Banking::Messages::Transfer.new(
          sender: client,
          from_account: source_account,
          to_account: source_account,
          amount: 500,
          reference: 'Invalid transfer'
        )

        operator.send(transfer_message)
        status, error = client.take

        expect(status).to eq(:error)
        expect(error).to eq('Source and destination accounts cannot be the same')
      end
    end

    describe 'authorization' do
      let(:client2) do
        Ractor.new(name: 'client2') do
          receive
        end
      end

      after do
        client2.send(:close)
        loop do
          client2.take
        end
      rescue Ractor::ClosedError
        # Client closed
      end

      it 'prevents unauthorized access to accounts' do
        # Create account with different client ID
        create_message = Banking::Messages::CreateAccount.new(
          sender: client2,
          name: 'Other Client Account',
          initial_balance: 1000
        )

        operator.send(create_message)
        _, account_id = client2.take

        # Try to access with different client ID
        balance_message = Banking::Messages::Balance.new(
          sender: client,
          account_id: account_id
        )

        operator.send(balance_message)
        status, error = client.take

        expect(status).to eq(:error)
        expect(error).to eq('Unauthorized')
      end
    end

    describe 'time management' do
      it 'advances system time' do
        new_time = simulation_time + 3600 # Advance by 1 hour
        message = Banking::Messages::AdvanceTime.new(
          sender: client,
          new_time: new_time
        )

        operator.send(message)
        status, result = client.take

        expect(status).to eq(:ok)
        expect(result).to eq(new_time)
      end

      it 'prevents moving time backwards' do
        new_time = simulation_time - 3600 # Go back 1 hour
        message = Banking::Messages::AdvanceTime.new(
          sender: client,
          new_time: new_time
        )

        operator.send(message)
        status, error = client.take

        expect(status).to eq(:error)
        expect(error).to eq('Time cannot move backwards')
      end
    end

    describe 'transaction history' do
      let(:account_id) do
        message = Banking::Messages::CreateAccount.new(
          sender: client,
          name: 'Transaction Test Account',
          initial_balance: 1000
        )
        operator.send(message)
        _, id = client.take
        id
      end

      it 'retrieves account transactions' do
        message = Banking::Messages::Transactions.new(
          sender: client,
          account_id: account_id
        )

        operator.send(message)
        status, transactions = client.take

        expect(status).to eq(:ok)
        expect(transactions).to be_an(Array)
        expect(transactions.length).to eq(1)
        expect(transactions.first.amount).to eq(1000)
        expect(transactions.first.description).to eq('Initial balance')
      end
    end
  end
end
