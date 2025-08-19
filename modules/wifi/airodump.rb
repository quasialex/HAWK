# modules/wifi/airodump.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class WifiAirodump < ModuleBase
    def self.id      ; 'wifi_airodump' ; end
    def self.category; :wifi           ; end
    def self.label   ; 'Airodump'      ; end
    def self.icon    ; '📡'            ; end

    def self.actions
      [
        {
          id:'scan',
          label:'Run Airodump',
          description:'Live capture beacons/clients; optional channel/BSSID.',
          inputs:[
            {name:'iface',   label:'Interface (monitor)', type:'text', placeholder:'wlan0mon'},
            {name:'channel', label:'Channel (optional)',  type:'text', placeholder:'11'},
            {name:'bssid',   label:'BSSID (optional)',    type:'text', placeholder:'AA:BB:CC:DD:EE:FF'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      return unless action_id == 'scan'
      iface   = (p['iface'].to_s.empty? ? cfg['interfaces']['wifi_mon'] : p['iface']).to_s
      ch      = p['channel'].to_s.strip
      bssid   = p['bssid'].to_s.strip

      base = File.join(cfg['paths']['logs'], "airodump-#{Hackberry::Exec.timestamp}")
      log  = "#{base}.log"
      csv  = "#{base}.csv"

      args = []
      args << "--channel #{ch}" unless ch.empty?
      args << "--bssid #{bssid}" unless bssid.empty?
      args << "--write-interval 1"
      args << "--write #{base}"
      args << iface

      cmd = "airodump-ng #{args.join(' ')}"
      Hackberry::Exec.tmux_run(name:'airodump', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::WifiAirodump)
