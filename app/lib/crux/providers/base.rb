module Crux
  module Providers
    # Abstract interface every provider (Mock now, real adapters in crx-006)
    # implements identically, so Crux::Agents::Runner never branches on which
    # provider it's talking to.
    #
    # #call(prompt:, context:, agent:) -> { content:, tokens_in:, tokens_out: }
    #
    # `context` may carry a `:model` key naming which model to address (the
    # agent's primary or fallback) and, for QA/testing only, a
    # `:simulate_failure` flag. Real provider adapters must resolve
    # credentials entirely within their own scope — never write an API key
    # or other secret into the prompt/context that Crux::Agents::Runner logs
    # to crux_runs.prompt_ref/context_refs (crx-004 Gate 2 finding #4,
    # carried forward for crx-006 to inherit).
    class Base
      def call(prompt:, context:, agent:)
        raise NotImplementedError, "#{self.class} must implement #call"
      end
    end
  end
end
