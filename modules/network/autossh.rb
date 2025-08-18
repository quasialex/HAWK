# modules/network/autossh.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class AutoSSH < ModuleBase
    def self.id; 'net_autossh'; end
    def self.category; :network; end
    def self.label; 'AutoSSH Reverse'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        { id:'rport', label:'Reverse port', description:'Expose local port via remote',
          inputs:[
            {name:'userhost', label:'user@host', type:'text', placeholder:'user@vps'},
            {name:'remote', label:'Remote bind host:port', type:'text', default:'0.0.0.0:4444'},
            {name:'local',  label:'Local host:port', type:'text', default:'127.0.0.1:4444'}
          ] }
      ]
    end

    def self.run(action_id, p, cfg)
      uh, r, l = p['userhost'], p['remote'], p['local']
      log = File.join(cfg['paths']['logs'], "autossh-#{Hackberry::Exec.timestamp}.log")
      cmd = "autossh -M 0 -N -o 'ServerAliveInterval 30' -o 'ServerAliveCountMax 3' -R #{r}:#{l} #{uh}"
      Hackberry::Exec.tmux_run(name:'autossh', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::AutoSSH)
