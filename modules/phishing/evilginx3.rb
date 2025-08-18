# modules/phishing/evilginx3.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Evilginx3 < ModuleBase
    def self.id; 'phish_evilginx3'; end
    def self.category; :phishing; end
    def self.label; 'Evilginx3'; end
    def self.icon; '🎣'; end

    def self.actions
      [
        {
          id:'start', label:'Start Service', description:'Launch with phishlets dir',
          inputs:[ {name:'phishlets', label:'Phishlets path', type:'text', placeholder:'/opt/evilginx/phishlets'} ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      dir = p['phishlets'] && !p['phishlets'].empty? ? p['phishlets'] : cfg['paths']['phishlets']
      log = File.join(cfg['paths']['logs'], "evilginx3-#{Hackberry::Exec.timestamp}.log")
      cmd = "evilginx -p #{dir}"
      Hackberry::Exec.tmux_run(name:'evilginx3', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Evilginx3)
