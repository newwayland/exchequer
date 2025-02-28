# frozen_string_literal: true

module Institutions
  # Functional module responsible for creating and authorising Central Funds accounts.
  # This setup follows the Exchequer Pyramid, ensuring proper cash flow management
  # between key government accounts at the Bank of England and the Treasury Deposits system.
  module CentralFundsSetup
    module_function

    # Sets up all required accounts and returns a structured hash of account references.
    #
    # @param log [Proc] Logger function - takes a single string argument when called
    # @param treasury_deposits [AuthorisedDepositSystem] Treasury Deposits system instance
    # @return [Hash] A nested hash containing all created accounts
    #
    # @api public
    def create_accounts(log, treasury_deposits)
      institutions = treasury_deposits.institutions

      {
        central_funds: create_central_funds_accounts(log, treasury_deposits, institutions),
        gbs_funds: create_gbs_funds_accounts(log, treasury_deposits, institutions),
        hmrc_funds: create_hmrc_funds_accounts(log, institutions),
        dmo_funds: create_dmo_funds_accounts(log, institutions)
      }
    end

    # Creates and authorises core Central Funds accounts, including NLF and CF.
    def create_central_funds_accounts(log, treasury_deposits, institutions)
      efa = institutions[:efa]
      central_funds = create_institution_accounts(
        account_holder: institutions[:boe],
        owner: efa,
        entity: institutions[:cga],
        accounts: {
          nlf: 'National Loans Fund Account',
          cf: 'Exchequer Account'
        }
      )

      central_funds[:wma] = institutions[:boe].create_account(entity: efa, name: 'Ways and Means Account')
      central_funds[:nlf_mirror] = treasury_deposits.create_mirror_account(entity: efa, name: 'National Loans Fund')
      central_funds[:cf_mirror] =
        treasury_deposits.create_mirror_account(entity: efa, name: 'Consolidated Fund Recourse')

      log.call('Created and Authorised Central Funds Accounts')
      central_funds
    end

    # Creates and authorises GBS accounts at the Bank of England and Treasury Deposits.
    def create_gbs_funds_accounts(log, treasury_deposits, institutions)
      gbs_funds = create_institution_accounts(
        account_holder: institutions[:boe],
        owner: institutions[:efa],
        entity: institutions[:gbs],
        accounts: {
          cash: 'GBS Cash Account',
          supply: 'GBS Supply Account',
          drawing: 'GBS Drawing Account'
        }
      )

      gbs_funds[:nlf] = treasury_deposits.create_account(entity: institutions[:efa], name: 'GBS Cash (NLF)')
      treasury_deposits.authorise_entity(
        owner: institutions[:efa],
        account_id: gbs_funds[:nlf],
        entity: institutions[:gbs]
      )

      log.call('Created and Authorised GBS Funds Accounts')
      gbs_funds
    end

    # Creates and authorises HMRC accounts at the Bank of England.
    def create_hmrc_funds_accounts(log, institutions)
      hmrc_funds = create_institution_accounts(
        account_holder: institutions[:boe],
        owner: institutions[:efa],
        entity: institutions[:hmrc],
        accounts: {
          general: 'HMRC General Account'
        }
      )

      log.call('Created and Authorised HMRC Funds Accounts')
      hmrc_funds
    end

    # Creates and authorises DMO accounts at the Bank of England.
    def create_dmo_funds_accounts(log, institutions)
      dmo_funds = create_institution_accounts(
        account_holder: institutions[:boe],
        owner: institutions[:efa],
        entity: institutions[:dmo],
        accounts: {
          dma: 'Debt Management Account',
          wma2: 'Ways and Means II Account'
        }
      )

      log.call('Created and Authorised DMO Funds Accounts')
      dmo_funds
    end

    # Creates institution accounts and grants authorisation.
    #
    # @param account_holder [Institution] The entity holding the accounts (e.g., BoE)
    # @param owner [Institution] The owner of the account (e.g., EFA)
    # @param entity [Institution] The entity being authorised
    # @param accounts [Hash] A mapping of account keys to account names
    # @return [Hash] A hash of created accounts
    def create_institution_accounts(account_holder:, owner:, entity:, accounts:)
      accounts.each_with_object({}) do |(key, name), funds|
        funds[key] = account_holder.create_account(entity: owner, name: name)
        account_holder.authorise_entity(
          owner: owner,
          account_id: funds[key],
          entity: entity
        )
      end
    end

    private_class_method :create_institution_accounts,
                         :create_dmo_funds_accounts,
                         :create_hmrc_funds_accounts,
                         :create_gbs_funds_accounts,
                         :create_central_funds_accounts
  end
end
