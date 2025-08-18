# modules/ble/ble_scan_bettercap.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class BLEScanBettercap < ModuleBase
    def self.id; 'ble_scan'; end
    def self.category; :ble; end
    def self.label; 'BLE Scan (Bettercap)'; end
    def self.icon; '🧿'; end

    def self.actions
      [
        {
          id: 'scan', label: 'Start BLE Scan',
          description: 'Bettercap BLE discovery & events stream',
          inputs: [ {name:'iface', label:'BLE iface', type:'text', placeholder:'hci0'} ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['ble'] : p['iface']
      log = File.join(cfg['paths']['logs'], "ble-scan-#{Hackberry::Exec.timestamp}.log")
      caplet = %(set ble.interface #{iface}; ble.recon on; events.stream on;)
      cmd = "bettercap -eval \"#{caplet}\""
      Hackberry::Exec.tmux_run(name:'ble-scan', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::BLEScanBettercap)
