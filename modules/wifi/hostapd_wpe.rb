# modules/wifi/hostapd_wpe.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class HostapdWPE < ModuleBase
    def self.id; 'wifi_hostapd_wpe'; end
    def self.category; :wifi; end
    def self.label; 'hostapd‑wpe (EAP creds)'; end
    def self.icon; '📶'; end

    def self.actions
      [
        { id:'start', label:'Start hostapd‑wpe', description:'Use default wpe config (edit on disk)', inputs:[ {name:'conf', label:'Config path', type:'text', default:'/etc/hostapd-wpe/hostapd-wpe.conf'} ] }
      ]
    end

    def self.run(action_id, p, cfg)
      conf = p['conf']
      log = File.join(cfg['paths']['logs'], "hostapd-wpe-#{Hackberry::Exec.timestamp}.log")
      cmd = "hostapd-wpe #{conf}"
      Hackberry::Exec.tmux_run(name:'hostapd-wpe', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::HostapdWPE)
