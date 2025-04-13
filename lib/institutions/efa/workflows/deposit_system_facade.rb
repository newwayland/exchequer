# frozen_string_literal: true

module Institutions
  # A generalized facade for deposit system operations that simplifies access
  # to account balances and transfers for a specific entity and system.
  #
  # This class encapsulates the entity parameter required by operations
  # to reduce duplication and improve readability of financial modules.
  #
  # @api public
  class DepositSystemFacade
    # Initialize a new deposit system facade for a specific entity
    #
    # @param system [#balance, #transfer] The deposit system (e.g., BoE, Treasury Deposits)
    # @param entity [Object] The authorization entity for the operations
    #
    # @api public
    def initialize(system, entity)
      @system = system
      @entity = entity
    end

    # Get the balance of an account
    #
    # @param account_id [String] Account identifier
    # @return [Numeric] Account balance
    #
    # @api public
    def balance(account_id:)
      @system.balance(entity: @entity, account_id: account_id)
    end

    # Transfer funds between accounts
    #
    # @param from [String] Source account identifier
    # @param to [String] Destination account identifier
    # @param amount [Numeric] Amount to transfer
    # @param reference [String] Transfer reference
    #
    # @api public
    def transfer(from:, to:, amount:, reference:)
      @system.transfer(
        entity: @entity,
        from: from,
        to: to,
        amount: amount,
        reference: reference
      )
    end
  end
end
