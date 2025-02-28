# frozen_string_literal: true

module Institutions
  # The ExchequerSweep module implements the Exchequer Pyramid process,
  # consolidating government cash balances at the end of each business day.
  #
  # This module uses the DepositSystemFacade to simplify operations with
  # different financial systems.
  #
  # @api public
  module ExchequerSweep
    module_function

    # Executes the Exchequer sweep process in four sequential steps.
    #
    # @param log [Method] Logging function (expects a single message string)
    # @param boe [Institution] Bank of England institution
    # @param efa [Institution] Exchequer Funds and Accounts institution
    # @param treasury_deposits [AuthorisedDepositSystem] HM Treasury Deposit System
    # @param accounts [Hash] Collection of relevant account identifiers
    #
    # @api public
    def execute(log, boe, efa, treasury_deposits, accounts)
      # Create facades to simplify operations
      boe_ops = DepositSystemFacade.new(boe, efa)
      treasury_ops = DepositSystemFacade.new(treasury_deposits, efa)

      # Step 1: Transfer the balance from the HMRC General Account to the Exchequer Account
      sweep_hmrc_to_exchequer(
        log,
        boe_ops,
        accounts[:hmrc_funds][:general],
        accounts[:central_funds][:cf]
      )

      # Step 2: Transfer the balance from the GBS Cash Account to the National Loans Fund (NLF)
      zero_gbs_cash(
        log,
        boe_ops,
        treasury_ops,
        accounts
      )

      # Step 3: Adjust the Exchequer Account balance with the NLF
      balance_exchequer_with_nlf(
        log,
        boe_ops,
        accounts[:central_funds][:cf],
        accounts[:central_funds][:nlf]
      )

      # Step 4: Adjust the NLF balance with the Debt Management Account (DMA)
      balance_nlf_with_dma(
        log,
        boe_ops,
        accounts[:central_funds][:nlf],
        accounts[:dmo_funds][:dma]
      )

      log.call('Completed Exchequer Sweep')
    end

    # Transfers all available funds from the HMRC General Account to the Exchequer Account.
    #
    # @param log [Method] Logging function
    # @param boe_ops [DepositSystemFacade] Facade for Bank of England operations
    # @param hmrc_account [String] HMRC General Account identifier
    # @param exchequer_account [String] Exchequer Account identifier
    #
    # @api private
    def sweep_hmrc_to_exchequer(log, boe_ops, hmrc_account, exchequer_account)
      sweep_balance = boe_ops.balance(account_id: hmrc_account)
      return if sweep_balance.zero?

      boe_ops.transfer(
        from: hmrc_account,
        to: exchequer_account,
        amount: sweep_balance,
        reference: 'HMRC Sweep'
      )
      log.call("Swept #{sweep_balance} from HMRC General Account to Exchequer Account")
    end

    # Transfers all available funds from the GBS Cash Account to the NLF,
    # ensuring the mirror account in EFA is updated accordingly.
    #
    # @param log [Method] Logging function
    # @param boe_ops [DepositSystemFacade] Facade for Bank of England operations
    # @param treasury_ops [DepositSystemFacade] Facade for Treasury Deposit operations
    # @param accounts [Hash] Collection of relevant account identifiers
    #
    # @api private
    def zero_gbs_cash(log, boe_ops, treasury_ops, accounts)
      gbs_cash_account = accounts[:gbs_funds][:cash]
      nlf_account = accounts[:central_funds][:nlf]
      nlf_mirror = accounts[:central_funds][:nlf_mirror]
      gbs_nlf_account = accounts[:gbs_funds][:nlf]

      ref = 'GBS Sweep'
      sweep_balance = boe_ops.balance(account_id: gbs_cash_account)
      return if sweep_balance.zero?

      boe_ops.transfer(
        from: gbs_cash_account,
        to: nlf_account,
        amount: sweep_balance,
        reference: ref
      )
      treasury_ops.transfer(
        from: nlf_mirror,
        to: gbs_nlf_account,
        amount: sweep_balance,
        reference: ref
      )
      log.call("Swept #{sweep_balance} from GBS Cash to National Loans Fund")
    end

    # Balances the Exchequer Account by transferring surplus to the NLF
    # or covering a deficit from the NLF.
    #
    # @param log [Method] Logging function
    # @param boe_ops [DepositSystemFacade] Facade for Bank of England operations
    # @param exchequer_account [String] Exchequer Account identifier
    # @param nlf_account [String] National Loans Fund Account identifier
    #
    # @api private
    def balance_exchequer_with_nlf(log, boe_ops, exchequer_account, nlf_account)
      exchequer_balance = boe_ops.balance(account_id: exchequer_account)
      if exchequer_balance.positive?
        # Exchequer in surplus - transfer to NLF (no Comptroller authorization needed)
        boe_ops.transfer(
          from: exchequer_account,
          to: nlf_account,
          amount: exchequer_balance,
          reference: 'Exchequer Surplus'
        )
        log.call("Transferred #{exchequer_balance} Exchequer surplus to NLF")
      elsif exchequer_balance.negative?
        # Exchequer in deficit - transfer from NLF (no Comptroller authorization needed)
        deficit = exchequer_balance.abs
        boe_ops.transfer(
          from: nlf_account,
          to: exchequer_account,
          amount: deficit,
          reference: 'Exchequer Deficit'
        )
        log.call("Transferred #{deficit} from NLF to cover Exchequer deficit")
      end
    end

    # Balances the NLF by transferring surplus to the DMA or covering a deficit from the DMA.
    #
    # @param log [Method] Logging function
    # @param boe_ops [DepositSystemFacade] Facade for Bank of England operations
    # @param nlf_account [String] National Loans Fund Account identifier
    # @param dma_account [String] Debt Management Account identifier
    #
    # @api private
    def balance_nlf_with_dma(log, boe_ops, nlf_account, dma_account)
      nlf_balance = boe_ops.balance(account_id: nlf_account)
      if nlf_balance.negative?
        # NLF in deficit - transfer from DMA
        deficit = nlf_balance.abs
        boe_ops.transfer(
          from: dma_account,
          to: nlf_account,
          amount: deficit,
          reference: 'NLF Deficit'
        )
        log.call("Transferred #{deficit} from DMA to cover NLF deficit")
      elsif nlf_balance.positive?
        # NLF in surplus - transfer to DMA
        boe_ops.transfer(
          from: nlf_account,
          to: dma_account,
          amount: nlf_balance,
          reference: 'NLF Surplus'
        )
        log.call("Transferred #{nlf_balance} NLF surplus to DMA")
      end
    end

    private_class_method :sweep_hmrc_to_exchequer, :zero_gbs_cash, :balance_exchequer_with_nlf, :balance_nlf_with_dma
  end
end
