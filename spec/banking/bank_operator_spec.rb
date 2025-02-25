# frozen_string_literal: true

require 'banking'
require 'time'

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
