# frozen_string_literal: true

require 'institutions'
describe Institutions::CentralFundsSetup do
  let(:log) { instance_double(Proc, call: nil) }
  let(:boe) do
    instance_double(Banking::AuthorisedDepositSystem, 'BOE', create_account: 'account_id', authorise_entity: nil)
  end
  let(:efa) { instance_double(Institutions::ExchequerFundsAndAccounts, 'EFA') }
  let(:cga) { instance_double(Banking::AuthorisedDepositSystem, 'CGA') }
  let(:gbs) { instance_double(Banking::AuthorisedDepositSystem, 'GBS') }
  let(:hmrc) { instance_double(Banking::AuthorisedDepositSystem, 'HMRC') }
  let(:dmo) { instance_double(Banking::AuthorisedDepositSystem, 'DMO') }
  let(:treasury_deposits) do
    instance_double(Banking::AuthorisedDepositSystem, 'NLF Deposits',
                    create_mirror_account: 'mirror_account_id',
                    create_account: 'account_id',
                    authorise_entity: nil,
                    institutions: {
                      boe: boe,
                      efa: efa,
                      cga: cga,
                      gbs: gbs,
                      hmrc: hmrc,
                      dmo: dmo
                    })
  end

  describe '#create_accounts' do
    it 'creates and returns a structured hash of accounts' do
      result = described_class.create_accounts(log, treasury_deposits)

      expect(result).to include(:central_funds, :gbs_funds, :hmrc_funds, :dmo_funds)
    end
  end

  describe 'account creation methods' do
    shared_examples 'account creator' do |method, expected_log|
      it "calls #{method} and logs the correct message" do
        accounts = described_class.send(method, log, treasury_deposits, treasury_deposits.institutions)

        expect(accounts).to be_a(Hash)
        expect(log).to have_received(:call).with(expected_log)
      end
    end

    it_behaves_like 'account creator', :create_central_funds_accounts, 'Created and Authorised Central Funds Accounts'
    it_behaves_like 'account creator', :create_gbs_funds_accounts, 'Created and Authorised GBS Funds Accounts'
    # it_behaves_like 'account creator', :create_hmrc_funds_accounts, 'Created and Authorised HMRC Funds Accounts'
    # it_behaves_like 'account creator', :create_dmo_funds_accounts, 'Created and Authorised DMO Funds Accounts'
  end

  describe '#create_institution_accounts' do
    let(:accounts) do
      {
        test_account: 'Test Account'
      }
    end

    it 'creates accounts and authorises them' do
      result = described_class.send(:create_institution_accounts,
                                    account_holder: boe,
                                    owner: efa,
                                    entity: cga,
                                    accounts: accounts)

      expect(result).to include(:test_account)
      expect(boe).to have_received(:create_account).with(entity: efa, name: 'Test Account')
      expect(boe).to have_received(:authorise_entity).with(owner: efa, account_id: 'account_id', entity: cga)
    end
  end
end
