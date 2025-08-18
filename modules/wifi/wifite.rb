# modules/wifi/wifite.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Wifite < ModuleBase
    def self.id; 'wifi_wifite'; end
    def self.category; :wifi; end
    def self.label; 'Wifite Capture'; end
    def self.icon; '📶'; end

    def self.actions
      [
        {
          id: 'quick', label: 'Quick Capture',
          description: 'Auto‑scan & capture handshakes/PMKID non‑interactively',
          inputs: [
            {name:'iface', label:'Wi‑Fi iface', type:'text', default:nil, placeholder:'wlan0'},
            {name:'dur', label:'Duration (min)', type:'number', default:'10'}
          ]
        },
        {
          id: 'target', label: 'Targeted Capture',
          description: 'Capture specific BSSID/channel',
          inputs: [
            {name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'},
            {name:'bssid', label:'BSSID', type:'text', placeholder:'AA:BB:CC:DD:EE:FF'},
            {name:'channel', label:'Channel', type:'text', placeholder:'6'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
      capdir = cfg['paths']['captures']
      log = File.join(cfg['paths']['logs'], "wifite-#{Hackberry::Exec.timestamp}.log")

      case action_id
      when 'quick'
        dur = (p['dur'] || '10').to_i
        cmd = "timeout #{dur}m wifite -i #{iface} -mac --pmkid --no-colors -v -o #{capdir}"
        return Hackberry::Exec.tmux_run(name:'wifite', cmd: cmd, log_path: log)
      when 'target'
        b = p['bssid']
        c = p['channel']
        cmd = "wifite -i #{iface} -mac --pmkid --no-colors -v -o #{capdir} --bssid #{b} --channel #{c}"
        return Hackberry::Exec.tmux_run(name:'wifite', cmd: cmd, log_path: log)
      else
        raise 'unknown action'
      end
    end
  end
end

Hackberry::Registry.register(Hackberry::Wifite)
