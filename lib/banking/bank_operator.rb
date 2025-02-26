# frozen_string_literal: true

module Banking
  # BankOperator processes banking messages in a separate Ractor
  #
  # @api public
  class BankOperator
    # Starts a new bank operator in a separate Ractor
    #
    # @param name [String] bank name
    # @param simulation_time [Time] starting time
    # @param authorizations [Hash] initial auth mappings
    # @return [Ractor] the bank operator Ractor
    #
    # @api public
    def self.start(name:, simulation_time:, authorizations: {})
      Ractor.new(name, authorizations, simulation_time) do |bank_name, auths, time|
        operator = BankOperator.new(bank_name, auths, time)
        operator.run
      end
    end

    # @param name [String] bank name
    # @param authorizations [Hash] authorization mappings
    # @param simulation_time [Time] starting time
    def initialize(name, authorizations, simulation_time)
      @logger = Log.new("log/#{name.downcase.gsub(/\s+/, '_')}.log")
      @bank = DepositSystem.new(name, simulation_time, @logger)
      @message_handler = MessageHandler.new(@bank, authorizations)
    end

    # Runs the message processing loop
    #
    # @api private
    def run
      loop do
        message = Ractor.receive
        break if shutdown?(message)

        handle_broadcast_message(message) ||
          handle_response_message(message)
      end
    ensure
      cleanup
    end

    private

    # Handles any broadcast messages
    #
    # @param message [Message] the message to process
    # @api private
    def handle_broadcast_message(message)
      if message.instance_of?(Messages::InstitutionsDirectory)
        @institutions = message.directory
      else
        @logger.write(@bank.current_time, message.class)
        false
      end
    end

    # Handles an individual message
    #
    # @param message [Message] the message to process
    # @api private
    def handle_response_message(message)
      result = @message_handler.process(message)
      send_response(message, result)
    end

    # Sends response back to message sender
    #
    # @param message [Message] the original message
    # @param result [Result] the processing result
    # @api private
    def send_response(message, result)
      message.sender.send(result.to_response)
    rescue NoMethodError
      log_missing_sender(message, result)
    end

    # Logs error when sender is missing
    #
    # @param message [Message] the message with missing sender
    # @param result [Result] the processing result
    # @api private
    def log_missing_sender(message, result)
      @logger.write(@bank.current_time, "Missing sender in: #{message.inspect}")
      @logger.write(@bank.current_time, result.data)
    end

    # Checks if message is shutdown signal
    #
    # @param message [Object] the message to check
    # @return [Boolean] true if shutdown signal
    # @api private
    def shutdown?(message)
      message == :shutdown
    end

    # Performs cleanup operations
    #
    # @api private
    def cleanup
      @logger.close
    end
  end

  # Handles processing of banking messages
  #
  # @api private
  class MessageHandler
    # Maps message types to handler methods
    MESSAGE_HANDLERS = {
      Messages::CreateAccount => :handle_create_account,
      Messages::CreateMirrorAccount => :handle_create_mirror_account,
      Messages::Transfer => :handle_transfer,
      Messages::Balance => :handle_balance,
      Messages::Transactions => :handle_transactions,
      Messages::AdvanceTime => :handle_advance_time
    }.freeze

    # @param bank [DepositSystem] the banking system
    # @param authorizations [Hash] authorization mappings
    def initialize(bank, authorizations)
      @bank = bank
      @institutions = {}
      @authorizations = authorizations
      authorizations.default_proc = ->(hash, key) { hash[key] = [] }
    end

    # Processes an incoming message
    #
    # @param message [Message] the message to process
    # @return [Result] the processing result
    def process(message)
      auth = authorizations[message.sender]
      return Messages::Result.error('Unauthorized') unless message.authorized?(auth)

      handler_method = MESSAGE_HANDLERS[message.class]
      return Messages::Result.error('Unknown message type') unless handler_method

      send(handler_method, message)
    rescue StandardError => e
      Messages::Result.error(e.message)
    end

    private

    attr_reader :bank, :authorizations

    # @api private
    def handle_create_account(message)
      account_id = bank.create_account(name: message.name, initial_balance: message.initial_balance)
      authorizations[message.sender] << account_id
      Messages::Result.success(account_id)
    end

    # @api private
    def handle_create_mirror_account(message)
      account_id = bank.create_mirror_account(name: message.name, initial_balance: message.initial_balance)
      authorizations[message.sender] << account_id
      Messages::Result.success(account_id)
    end

    # @api private
    def handle_transfer(message)
      bank.transfer(from: message.from_account, to: message.to_account, amount: message.amount,
                    reference: message.reference)
      Messages::Result.success(true)
    end

    # @api private
    def handle_balance(message)
      Messages::Result.success(bank.balance(message.account_id))
    end

    # @api private
    def handle_transactions(message)
      Messages::Result.success(bank.transactions(message.account_id))
    end

    # @api private
    def handle_advance_time(message)
      bank.advance_time(message.new_time)
      Messages::Result.success(bank.current_time)
    end
  end

  private_constant :MessageHandler
end
