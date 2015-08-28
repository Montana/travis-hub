require 'travis/support/metrics'

require 'travis/addons'
require 'travis/event'
require 'travis/hub/support/amqp'
require 'travis/hub/support/sidekiq'

require 'travis/hub/model/log'
require 'travis/hub/model/log/part'

require 'travis/hub/app/dispatcher'
require 'travis/hub/app/solo'
require 'travis/hub/app/worker'

module Travis
  module Hub
    module App
      class << self
        TYPES = { 'solo' => Solo, 'worker' => Worker, 'dispatcher' => Dispatcher }

        def run(type, *args)
          setup
          setup_worker unless type == 'dispatcher'
          TYPES.fetch(type).new(type, *args).run
        end

        def setup
          Support::Amqp.setup(config.amqp)
          Travis::Metrics.setup
        end

        def setup_worker
          Travis::Database.connect
          # ActiveRecord::Base.logger = nil
          setup_logs_database if config.logs_database # TODO remove

          Support::Amqp.setup(config.amqp)
          Support::Sidekiq.setup(config)

          Travis::Event.setup(config.notifications) # TODO rename to :event_handlers
          Travis::Instrumentation.setup(logger)
          Travis::Exceptions::Reporter.start
          Travis::Encrypt.setup(key: config.encryption)

          # Travis.logger = Logger.configure(Logger.new(STDOUT))
        end

        def setup_logs_database
          [Log, Log::Part].each do |const|
            const.establish_connection 'logs_database'
          end
        end

        def logger
          Hub.logger
        end

        def config
          Hub.config
        end
      end
    end
  end
end