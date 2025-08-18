# modules/network/nmap_quick.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class NmapQuick < ModuleBase
    def self.id; 'net_nmap_quick'; end
    def self.category; :network; end
    def self.label; 'Quick Nmap'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        {
          id:'top100', label:'Top 100 Ports', description:'Fast scan common ports',
          inputs:[ {name:'target', label:'Target (CIDR/host)', type:'text', placeholder:'192.168.1.0/24'} ]
        },
        {
          id:'svc', label:'Service Detect', description:'Aggressive service detection',
          inputs:[ {name:'target', label:'Target', type:'text', placeholder:'host or CIDR'} ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      tgt = p['target'] || '192.168.1.0/24'
      log = File.join(cfg['paths']['logs'], "nmap-#{Hackberry::Exec.timestamp}.log")
      cmd = case action_id
      when 'top100'
        "nmap -T4 --top-ports 100 -Pn #{tgt}"
      when 'svc'
        "nmap -T4 -sV -O --version-light #{tgt}"
      else
        raise 'unknown action'
      end
      Hackberry::Exec.tmux_run(name:'nmap', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::NmapQuick)
