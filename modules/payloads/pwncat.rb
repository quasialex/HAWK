# modules/payloads/pwncat.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Pwncat < ModuleBase
    def self.id; 'pay_pwncat'; end
    def self.category; :payloads; end
    def self.label; 'pwncat-cs Listener'; end
    def self.icon; '📦'; end

    def self.actions
      [
        {
          id:'listen', label:'Start Listener', description:'pwncat-cs -l',
          inputs:[ {name:'lport', label:'LPORT', type:'number', default:'4444'} ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      port = (p['lport'] || '4444').to_i
      log = File.join(cfg['paths']['logs'], "pwncat-#{Hackberry::Exec.timestamp}.log")
      cmd = "pwncat-cs -lp #{port}"
      Hackberry::Exec.tmux_run(name:'pwncat', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Pwncat)
