# frozen_string_literal: true

require 'institutions'

RSpec.describe Institutions::ExchequerSweep do
  let(:logger) { double('Logger') }
  let(:boe) { double('Bank of England') }
  let(:efa) { double('Exchequer Funds and Accounts') }
  let(:treasury_deposits) { double('Treasury Deposits') }

  let(:accounts) do
    {
      hmrc_funds: {
        general: 'HMRC-GENERAL'
      },
      central_funds: {
        cf: 'EXCHEQUER-ACCOUNT',
        nlf: 'NLF-ACCOUNT',
        nlf_mirror: 'NLF-MIRROR'
      },
      gbs_funds: {
        cash: 'GBS-CASH',
        nlf: 'GBS-NLF'
      },
      dmo_funds: {
        dma: 'DMA-ACCOUNT'
      }
    }
  end

  let(:boe_facade) { instance_double(Institutions::DepositSystemFacade) }
  let(:treasury_facade) { instance_double(Institutions::DepositSystemFacade) }

  before do
    allow(Institutions::DepositSystemFacade).to receive(:new).with(boe, efa).and_return(boe_facade)
    allow(Institutions::DepositSystemFacade).to receive(:new).with(treasury_deposits, efa).and_return(treasury_facade)
    allow(logger).to receive(:call)

    # Allow any transfer to avoid unexpected arguments errors
    allow(boe_facade).to receive(:transfer)
    allow(treasury_facade).to receive(:transfer)
  end

  describe '.execute' do
    it 'processes all sweep steps in the correct order' do
      # Setup for Step 1: HMRC to Exchequer
      allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(1000)

      # Setup for Step 2: GBS Cash to NLF
      allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(2000)

      # Setup for Step 3: Exchequer with NLF (surplus case)
      allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(500)

      # Setup for Step 4: NLF with DMA (surplus case)
      allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(2500)

      # Execute the sweep process
      described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

      # Verify all expected steps were called
      expect(boe_facade).to have_received(:balance).with(account_id: accounts[:hmrc_funds][:general])
      expect(boe_facade).to have_received(:balance).with(account_id: accounts[:gbs_funds][:cash])
      expect(boe_facade).to have_received(:balance).with(account_id: accounts[:central_funds][:cf])
      expect(boe_facade).to have_received(:balance).with(account_id: accounts[:central_funds][:nlf])

      # Verify the correct transfers were made
      expect(boe_facade).to have_received(:transfer).with(
        from: accounts[:hmrc_funds][:general],
        to: accounts[:central_funds][:cf],
        amount: 1000,
        reference: 'HMRC Sweep'
      )

      expect(boe_facade).to have_received(:transfer).with(
        from: accounts[:gbs_funds][:cash],
        to: accounts[:central_funds][:nlf],
        amount: 2000,
        reference: 'GBS Sweep'
      )

      expect(treasury_facade).to have_received(:transfer).with(
        from: accounts[:central_funds][:nlf_mirror],
        to: accounts[:gbs_funds][:nlf],
        amount: 2000,
        reference: 'GBS Sweep'
      )

      expect(boe_facade).to have_received(:transfer).with(
        from: accounts[:central_funds][:cf],
        to: accounts[:central_funds][:nlf],
        amount: 500,
        reference: 'Exchequer Surplus'
      )

      expect(boe_facade).to have_received(:transfer).with(
        from: accounts[:central_funds][:nlf],
        to: accounts[:dmo_funds][:dma],
        amount: 2500,
        reference: 'NLF Surplus'
      )

      expect(logger).to have_received(:call).with('Swept 1000 from HMRC General Account to Exchequer Account')
      expect(logger).to have_received(:call).with('Swept 2000 from GBS Cash to National Loans Fund')
      expect(logger).to have_received(:call).with('Transferred 500 Exchequer surplus to NLF')
      expect(logger).to have_received(:call).with('Transferred 2500 NLF surplus to DMA')
      expect(logger).to have_received(:call).with('Completed Exchequer Sweep')
    end

    context 'when HMRC has zero balance' do
      it 'skips the HMRC transfer step' do
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(0)

        described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

        expect(boe_facade).not_to have_received(:transfer).with(
          from: accounts[:hmrc_funds][:general],
          to: anything,
          amount: anything,
          reference: 'HMRC Sweep'
        )
      end
    end

    context 'when GBS Cash has zero balance' do
      it 'skips the GBS Cash transfer step' do
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(0)

        described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

        expect(boe_facade).not_to have_received(:transfer).with(
          from: accounts[:gbs_funds][:cash],
          to: anything,
          amount: anything,
          reference: 'GBS Sweep'
        )
      end
    end

    context 'when Exchequer has zero balance' do
      it 'skips the Exchequer balance step' do
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(0)

        described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

        expect(boe_facade).not_to have_received(:transfer).with(
          from: accounts[:central_funds][:cf],
          to: anything,
          amount: anything,
          reference: anything
        )

        expect(boe_facade).not_to have_received(:transfer).with(
          from: accounts[:central_funds][:nlf],
          to: accounts[:central_funds][:cf],
          amount: anything,
          reference: anything
        )
      end
    end

    context 'when Exchequer has negative balance' do
      it 'transfers from NLF to cover the deficit' do
        # All balances in the flow
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(-800)
        # Important: Set NLF balance to 0 to avoid triggering the NLF to DMA transfer
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(0)

        described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

        # Check the specific transfer for the Exchequer deficit
        expect(boe_facade).to have_received(:transfer).with(
          from: accounts[:central_funds][:nlf],
          to: accounts[:central_funds][:cf],
          amount: 800,
          reference: 'Exchequer Deficit'
        )

        expect(logger).to have_received(:call).with('Transferred 800 from NLF to cover Exchequer deficit')
      end
    end

    context 'when NLF has negative balance' do
      it 'transfers from DMA to cover the deficit' do
        # All balances in the flow
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(-1500)

        described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

        # Check the specific transfer for the NLF deficit
        expect(boe_facade).to have_received(:transfer).with(
          from: accounts[:dmo_funds][:dma],
          to: accounts[:central_funds][:nlf],
          amount: 1500,
          reference: 'NLF Deficit'
        )

        expect(logger).to have_received(:call).with('Transferred 1500 from DMA to cover NLF deficit')
      end
    end

    context 'when NLF has zero balance' do
      it 'skips the NLF balance step' do
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:hmrc_funds][:general]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:gbs_funds][:cash]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:cf]).and_return(0)
        allow(boe_facade).to receive(:balance).with(account_id: accounts[:central_funds][:nlf]).and_return(0)

        described_class.execute(logger.method(:call), boe, efa, treasury_deposits, accounts)

        expect(boe_facade).not_to have_received(:transfer).with(
          from: accounts[:central_funds][:nlf],
          to: accounts[:dmo_funds][:dma],
          amount: anything,
          reference: 'NLF Surplus'
        )

        expect(boe_facade).not_to have_received(:transfer).with(
          from: accounts[:dmo_funds][:dma],
          to: accounts[:central_funds][:nlf],
          amount: anything,
          reference: 'NLF Deficit'
        )
      end
    end
  end
end
