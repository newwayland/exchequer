# frozen_string_literal: true

require 'banking'
require 'time'

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

  describe Banking::Messages::CreateMirrorAccount do
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
