# modules/wifi/airodump.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Airodump < ModuleBase
    def self.id; 'wifi_airodump'; end
    def self.category; :wifi; end
    def self.label; 'Airodump Recon'; end
    def self.icon; '📶'; end

    def self.actions
      [
        { id:'recon', label:'Recon (CSV)', description:'Capture beacons/clients to CSV',
          inputs:[
            {name:'iface', label:'Monitor iface', type:'text', placeholder:'wlan0mon'},
            {name:'chan', label:'Channels (opt)', type:'text', placeholder:'1,6,11'},
            {name:'mins', label:'Duration (min)', type:'number', default:'5'}
          ] }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi_mon'] : p['iface']
      ch = p['chan']; chopt = ch && !ch.empty? ? "-c #{ch}" : ''
      mins = (p['mins'] || '5').to_i
      base = File.join(cfg['paths']['captures'], "airodump-#{Hackberry::Exec.timestamp}")
      log = File.join(cfg['paths']['logs'], "airodump-#{Hackberry::Exec.timestamp}.log")
      cmd = "timeout #{mins}m airodump-ng #{chopt} --output-format csv -w #{base} #{iface}"
      Hackberry::Exec.tmux_run(name:'airodump', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Airodump)
