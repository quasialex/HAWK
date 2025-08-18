# modules/wifi/wifiphisher.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Wifiphisher < ModuleBase
    def self.id; 'wifi_wifiphisher'; end
    def self.category; :wifi; end
    def self.label; 'Wifiphisher (Rogue AP)'; end
    def self.icon; '📶'; end

    def self.actions
      [
        {
          id:'auto', label:'Auto Rogue AP', description:'Launch default phishing scenario',
          inputs:[
            {name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'},
            {name:'essid', label:'Target ESSID (opt)', type:'text', placeholder:'clone from air'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
      essid = p['essid']
      log = File.join(cfg['paths']['logs'], "wifiphisher-#{Hackberry::Exec.timestamp}.log")
      cmd = "wifiphisher -i #{iface}"
      cmd += " -e \"#{essid}\"" if essid && !essid.empty?
      Hackberry::Exec.tmux_run(name:'wifiphisher', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Wifiphisher)
