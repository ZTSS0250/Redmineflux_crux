module Crux
  module Providers
    # Raised by any provider implementation when a model call fails (a
    # simulated failure for Mock; a real API error once crx-006 lands real
    # adapters). Crux::Agents::Runner rescues this to drive its fallback-
    # model retry. Kept in its own file (rather than alongside Base) so
    # Rails autoloading always finds exactly one constant per file.
    class Error < StandardError; end
  end
end
