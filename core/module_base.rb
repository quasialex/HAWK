# core/module_base.rb
module Hackberry
  class ModuleBase
    def self.id; raise NotImplementedError; end
    def self.category; raise NotImplementedError; end   # :wifi, :ble, :network, :payloads, :phishing
    def self.label; raise NotImplementedError; end
    def self.icon; '🛠️'; end

    # Describe available actions and their input fields.
    # Each action: { id:, label:, description:, inputs: [ {name:, label:, type:, placeholder:, default:, options:[] } ] }
    def self.actions; []; end

    # Execute action with params (Hash)
    def self.run(action_id, params, cfg); raise NotImplementedError; end
  end
end
