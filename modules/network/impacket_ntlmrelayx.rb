# modules/network/impacket_ntlmrelayx.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class NTLMRelayX < ModuleBase
    def self.id; 'net_ntlmrelayx'; end
    def self.category; :network; end
    def self.label; 'Impacket ntlmrelayx'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        {
          id:'smb_http', label:'Relay SMB→LDAP/HTTP', description:'Basic relay to dump or add admin (test env!)',
          inputs:[
            {name:'targets', label:'Target hosts file or URL(s)', type:'text', placeholder:'targets.txt or http://ip:port'},
            {name:'no_smb', label:'Disable SMB server? (y/n)', type:'text', default:'n'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      targets = p['targets'] || 'targets.txt'
      nosmb = (p['no_smb'] || 'n').downcase.start_with?('y')
      log = File.join(cfg['paths']['logs'], "ntlmrelayx-#{Hackberry::Exec.timestamp}.log")
      cmd = "ntlmrelayx.py -tf #{targets}"
      cmd += " --no-smb-server" if nosmb
      Hackberry::Exec.tmux_run(name:'ntlmrelayx', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::NTLMRelayX)
