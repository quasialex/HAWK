# modules/ble/blue_hydra.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class BlueHydra < ModuleBase
    def self.id; 'ble_bluehydra'; end
    def self.category; :ble; end
    def self.label; 'Blue-Hydra Passive'; end
    def self.icon; '🧿'; end

    def self.actions
      [
        { id:'run', label:'Passive Scan', description:'Blue-Hydra discovery', inputs: [] }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "blue-hydra-#{Hackberry::Exec.timestamp}.log")
      cmd = "blue-hydra"
      Hackberry::Exec.tmux_run(name:'bluehydra', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::BlueHydra)
