# frozen_string_literal: true

require 'banking'

describe Banking::AuthorisedDepositSystem do
  bank_name = 'Test Bank'
  simulation_time = Time.new(2025, 2, 27, 10, 0, 0)
  simulation_time_format = Log.format(simulation_time, '').chomp

  let(:logger) { instance_double(Log, :<< => true, close: true) }
  let(:first_customer) { instance_double(Object, 'First Customer') }
  let(:second_customer) { instance_double(Object, 'Second Customer') }
  let(:deposit_system) { instance_double(Banking::DepositSystem, current_time: simulation_time, advance_time: nil) }

  let(:deposit_notifier) do
    class_double(Banking::DepositSystem).as_stubbed_const
  end

  let(:auth_system) { described_class.new(name: bank_name, simulation_time: simulation_time, logger: logger) }

  before do
    allow(deposit_notifier).to receive(:new).and_return(deposit_system)
  end

  describe '#initialize' do
    it 'creates a new deposit system' do
      described_class.new(name: bank_name, simulation_time: simulation_time, logger: logger)
      expect(deposit_notifier).to have_received(:new)
    end

    it 'initializes with empty authorisations when none provided' do
      system = described_class.new(name: bank_name, simulation_time: simulation_time, logger: logger)
      expect(system.instance_variable_get(:@authorisations)).to be_a(Hash)
      expect(system.instance_variable_get(:@authorisations).default_proc).not_to be_nil
    end

    it 'initializes with provided authorisations' do
      initial_auths = { first_customer => Set.new(['account1']) }
      system = described_class.new(name: bank_name, simulation_time: simulation_time, logger: logger,
                                   authorisations: initial_auths)
      expect(system.instance_variable_get(:@authorisations)).to eq(initial_auths)
    end
  end

  describe '#current_time' do
    it 'delegates to deposit system' do
      auth_system.current_time
      expect(deposit_system).to have_received(:current_time)
    end
  end

  describe '#advance_time' do
    it 'delegates to deposit system' do
      auth_system.advance_time(simulation_time)
      expect(deposit_system).to have_received(:advance_time)
    end
  end

  describe '#update_institutions_directory' do
    it 'updates the institutions directory' do
      directory = { 'Bank1' => 'info1', 'Bank2' => 'info2' }

      result = auth_system.update_institutions_directory(directory)

      expect(result).to be true
      expect(logger).to have_received(:<<).with("#{simulation_time_format}Received Institution Directory\n")
      expect(auth_system.instance_variable_get(:@institutions)).to eq(directory)
    end
  end

  describe '#create_account' do
    let(:account_name) { 'Test Account' }
    let(:initial_balance) { 1000 }
    let(:account_id) { 'acc123' }

    before do
      allow(deposit_system).to receive(:create_account).and_return(account_id)
    end

    it 'delegates to deposit system and authorises the entity' do
      result = auth_system.create_account(entity: first_customer, name: account_name, initial_balance: initial_balance)

      expect(deposit_system).to have_received(:create_account).with(name: account_name,
                                                                    initial_balance: initial_balance)
      expect(result).to eq(account_id)
      expect(auth_system.instance_variable_get(:@authorisations)[first_customer]).to include(account_id)
    end

    it 'uses default initial balance when not provided' do
      auth_system.create_account(entity: first_customer, name: account_name)
      expect(deposit_system).to have_received(:create_account).with(name: account_name, initial_balance: 0)
    end
  end

  describe '#create_mirror_account' do
    let(:account_name) { 'Mirror Account' }
    let(:initial_balance) { 500 }
    let(:mirror_account_id) { 'mirror789' }

    before do
      allow(deposit_system).to receive(:create_mirror_account).and_return(mirror_account_id)
    end

    it 'delegates to deposit system and authorises the entity' do
      result = auth_system.create_mirror_account(entity: first_customer, name: account_name,
                                                 initial_balance: initial_balance)

      expect(deposit_system).to have_received(:create_mirror_account)
        .with(name: account_name, initial_balance: initial_balance)
      expect(result).to eq(mirror_account_id)
      expect(auth_system.instance_variable_get(:@authorisations)[first_customer]).to include(mirror_account_id)
    end
  end

  describe '#transfer' do
    let(:from_account) { 'from123' }
    let(:to_account) { 'to456' }
    let(:amount) { 200 }
    let(:reference) { 'Payment for services' }

    before do
      auth_system.instance_variable_get(:@authorisations)[first_customer] = Set.new([from_account])
      allow(deposit_system).to receive(:transfer).and_return(true)
    end

    it 'transfers money when entity is authorised' do
      result = auth_system.transfer(entity: first_customer, from: from_account, to: to_account, amount: amount,
                                    reference: reference)
      expect(deposit_system).to have_received(:transfer)
        .with(from: from_account, to: to_account, amount: amount, reference: reference)

      expect(result).to be true
    end

    it 'works with default reference' do
      auth_system.transfer(entity: first_customer, from: from_account, to: to_account, amount: amount)
      expect(deposit_system).to have_received(:transfer).with(from: from_account, to: to_account, amount: amount,
                                                              reference: nil)
    end

    it 'raises error when entity is not authorised' do
      expect do
        auth_system.transfer(entity: second_customer, from: from_account, to: to_account, amount: amount)
      end.to raise_error(Banking::UnauthorisedAccessError)

      expect(logger).to have_received(:<<)
        .with("#{simulation_time_format}Unauthorised access to account #{from_account} by #{second_customer}\n")
      expect(deposit_system).not_to have_received(:transfer)
    end
  end

  describe '#balance' do
    let(:account_id) { 'acc123' }
    let(:account_balance) { 1500 }

    before do
      auth_system.instance_variable_get(:@authorisations)[first_customer] = Set.new([account_id])
      allow(deposit_system).to receive(:balance).and_return(account_balance)
    end

    it 'returns balance when entity is authorised' do
      result = auth_system.balance(entity: first_customer, account_id: account_id)

      expect(deposit_system).to have_received(:balance).with(account_id)
      expect(result).to eq(account_balance)
    end

    it 'raises error when entity is not authorised' do
      expect do
        auth_system.balance(entity: second_customer, account_id: account_id)
      end.to raise_error(Banking::UnauthorisedAccessError)

      expect(logger).to have_received(:<<)
        .with("#{simulation_time_format}Unauthorised access to account #{account_id} by #{second_customer}\n")
      expect(deposit_system).not_to have_received(:balance)
    end
  end

  describe '#transactions' do
    let(:account_id) { 'acc123' }
    let(:transactions) { [{ id: 'tx1', amount: 100 }, { id: 'tx2', amount: -50 }] }

    before do
      auth_system.instance_variable_get(:@authorisations)[first_customer] = Set.new([account_id])
      allow(deposit_system).to receive(:transactions).and_return(transactions)
    end

    it 'returns transactions when entity is authorised' do
      result = auth_system.transactions(entity: first_customer, account_id: account_id)

      expect(deposit_system).to have_received(:transactions).with(account_id)
      expect(result).to eq(transactions)
    end

    it 'raises error when entity is not authorised' do
      expect do
        auth_system.transactions(entity: second_customer, account_id: account_id)
      end.to raise_error(Banking::UnauthorisedAccessError)

      expect(logger).to have_received(:<<)
        .with("#{simulation_time_format}Unauthorised access to account #{account_id} by #{second_customer}\n")
      expect(deposit_system).not_to have_received(:transactions)
    end
  end

  describe '#authorise_entity' do
    let(:account_id) { 'acc123' }

    before do
      auth_system.instance_variable_get(:@authorisations)[first_customer] = Set.new([account_id])
    end

    it 'authorises another entity when owner is authorised' do
      result = auth_system.authorise_entity(owner: first_customer, account_id: account_id, entity: second_customer)

      expect(result).to be true
      expect(auth_system.instance_variable_get(:@authorisations)[second_customer]).to include(account_id)
    end

    it 'raises error when owner is not authorised' do
      unauthorised_owner = instance_double(Object, 'Unauthorised owner')

      expect do
        auth_system.authorise_entity(owner: unauthorised_owner, account_id: account_id, entity: second_customer)
      end.to raise_error(Banking::UnauthorisedAccessError)

      expect(logger).to have_received(:<<)
        .with("#{simulation_time_format}Unauthorised access to account #{account_id} by #{unauthorised_owner}\n")
      expect(auth_system.instance_variable_get(:@authorisations)[second_customer]).not_to include(account_id)
    end
  end

  describe '#shutdown' do
    it 'logs shutdown message and closes logger' do
      auth_system.shutdown
      expect(logger).to have_received(:<<).with("#{simulation_time_format}Shutting down\n")
      expect(logger).not_to have_received(:close)
    end
  end

  describe 'private #authorise!' do
    let(:account_id) { 'acc123' }

    it 'returns true when entity is authorised' do
      auth_system.instance_variable_get(:@authorisations)[first_customer] = Set.new([account_id])

      result = auth_system.send(:authorise!, first_customer, account_id)

      expect(result).to be true
    end

    it 'raises error when entity is not authorised' do
      expect do
        auth_system.send(:authorise!, first_customer, account_id)
      end.to raise_error(Banking::UnauthorisedAccessError)
      expect(logger).to have_received(:<<)
        .with("#{simulation_time_format}Unauthorised access to account #{account_id} by #{first_customer}\n")
    end
  end
end
