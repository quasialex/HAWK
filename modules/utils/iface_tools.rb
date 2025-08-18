# modules/utils/iface_tools.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class IfaceTools < ModuleBase
    def self.id; 'utils_iface'; end
    def self.category; :utils; end
    def self.label; 'Interface Tools'; end
    def self.icon; '🧰'; end

    def self.actions
      [
        { id:'mon_start', label:'Enable Monitor Mode', description:'airmon-ng start', inputs:[{name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'}] },
        { id:'mon_stop',  label:'Disable Monitor Mode', description:'airmon-ng stop', inputs:[{name:'iface', label:'Monitor iface', type:'text', placeholder:'wlan0mon'}] },
        { id:'mac_rand',  label:'Randomize MAC', description:'macchanger -r', inputs:[{name:'iface', label:'Iface', type:'text', placeholder:'wlan0'}] },
        { id:'psave_off', label:'Power Save OFF', description:'iw set power_save off', inputs:[{name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'}] }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'] || cfg['interfaces']['wifi']
      log = File.join(cfg['paths']['logs'], "iface-#{Hackberry::Exec.timestamp}.log")
      cmd = case action_id
      when 'mon_start' then "airmon-ng start #{iface}"
      when 'mon_stop'  then "airmon-ng stop #{iface}"
      when 'mac_rand'  then "ifconfig #{iface} down && macchanger -r #{iface} && ifconfig #{iface} up"
      when 'psave_off' then "iw dev #{iface} set power_save off"
      else raise 'unknown'
      end
      Hackberry::Exec.tmux_run(name:'iface', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::IfaceTools)
