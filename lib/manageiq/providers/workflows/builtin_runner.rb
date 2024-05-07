module ManageIQ
  module Providers
    module Workflows
      require "floe"

      class BuiltinRunnner < Floe::Runner
        SCHEME = "builtin".freeze

        def run_async!(resource, params = {}, secrets = {}, context = {})
          scheme_prefix = "#{SCHEME}://"
          raise ArgumentError, "Invalid resource" unless resource&.start_with?(scheme_prefix)

          method = resource.sub(scheme_prefix, "")

          runner_context = {"method" => method}

          # TODO: prevent calling anything except the specifics methods, e.g. you shouldn't be able to call .to_s.
          #       Maybe make BuiltinMethods a BasicObject?
          method_result = BuiltinMethods.public_send(method, params, secrets, context)
          method_result.merge(runner_context)
        rescue => err
          cleanup(runner_context)
          error!(runner_context, :cause => err.to_s)
        end

        def cleanup(runner_context)
          method = runner_context["method"]
          raise ArgumentError if method.nil?

          cleanup_method = "#{method}_cleanup"
          return unless BuiltinMethods.respond_to?(cleanup_method, true)

          BuiltinMethods.send(cleanup_method, runner_context)
        end

        def wait(timeout: nil, events: %i[create update delete])
          # TODO: wait_for_task?
        end

        def status!(runner_context)
          method = runner_context["method"]
          raise ArgumentError if method.nil?

          BuiltinMethods.send("#{method}_status!", runner_context)
        end

        def running?(runner_context)
          runner_context["running"]
        end

        def success?(runner_context)
          runner_context["success"]
        end

        def output(runner_context)
          runner_context["output"]
        end

        def self.error!(runner_context = {}, cause:, error: "States.TaskFailed")
          runner_context.merge!(
            "running" => false, "success" => false, "output" => {"Error" => error, "Cause" => cause}
          )
        end
      end
    end
  end
end

Floe::Runner.register_scheme(ManageIQ::Providers::Workflows::BuiltinRunnner::SCHEME, ManageIQ::Providers::Workflows::BuiltinRunnner.new)
