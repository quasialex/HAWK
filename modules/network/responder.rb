# modules/network/responder.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Responder < ModuleBase
    def self.id; 'net_responder'; end
    def self.category; :network; end
    def self.label; 'Responder (LLMNR/NBT-NS)'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        { id:'start', label:'Start Responder', description:'Poison & capture', inputs: [ {name:'iface', label:'Interface', type:'text', placeholder:'eth0'} ] },
        { id:'stop', label:'Stop Responder', description:'Kill process', inputs: [] }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "responder-#{Hackberry::Exec.timestamp}.log")
      case action_id
      when 'start'
        iface = p['iface'] || cfg['interfaces']['lan']
        cmd = "responder -I #{iface} -wd"
        Hackberry::Exec.tmux_run(name:'responder', cmd: cmd, log_path: log)
      when 'stop'
        Hackberry::Exec.run_capture("pkill -f 'responder -I'")
      end
    end
  end
end

Hackberry::Registry.register(Hackberry::Responder)
