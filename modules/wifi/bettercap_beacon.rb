# modules/wifi/bettercap_beacon.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class BettercapBeacon < ModuleBase
    def self.id; 'wifi_beacon'; end
    def self.category; :wifi; end
    def self.label; 'Bettercap: Beacon Spam'; end
    def self.icon; '📡'; end

    def self.actions
      [
        {
          id: 'spam', label: 'Start Beacon Spam',
          description: 'Broadcast fake SSIDs with Bettercap caplet',
          inputs: [
            {name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'},
            {name:'ssid', label:'SSID Prefix', type:'text', placeholder:'Hackberry_'},
            {name:'count', label:'Number', type:'number', default:'20'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
      prefix = p['ssid'] || 'Hackberry_'
      count = (p['count'] || '20').to_i
      log = File.join(cfg['paths']['logs'], "bettercap-beacon-#{Hackberry::Exec.timestamp}.log")
      caplet = %(set wifi.interface #{iface}; wifi.recon on; wifi.show; set wifi.ap.ssid #{prefix}; set wifi.ap.count #{count}; wifi.ap.start; events.stream on;)
      cmd = "bettercap -eval \"#{caplet}\""
      Hackberry::Exec.tmux_run(name:'bcap-beacon', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::BettercapBeacon)
