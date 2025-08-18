# modules/payloads/msf_rpcd.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class MsfRPCD < ModuleBase
    def self.id; 'pay_msf_rpcd'; end
    def self.category; :payloads; end
    def self.label; 'Metasploit RPCd (msgrpc)'; end
    def self.icon; '📦'; end

    def self.actions
      [
        { id:'start', label:'Start RPC', description:'Launch msfconsole with msgrpc', inputs:[ {name:'user', label:'User', type:'text', default:'msf'}, {name:'pass', label:'Pass', type:'text', default:'msf'}, {name:'port', label:'Port', type:'number', default:'55553'}, {name:'ssl', label:'SSL (true/false)', type:'text', default:'false'} ] },
        { id:'stop',  label:'Stop RPC', description:'Kill msfconsole (msgrpc)', inputs:[] }
      ]
    end

    def self.run(action_id, p, cfg)
      case action_id
      when 'start'
        user, pass = p['user'], p['pass']
        port = (p['port'] || '55553').to_i
        ssl  = (p['ssl'] || 'false')
        rc = File.join(cfg['paths']['captures'], "msgrpc-#{Hackberry::Exec.timestamp}.rc")
        File.write(rc, <<~RC)
          load msgrpc ServerHost=127.0.0.1 ServerPort=#{port} User=#{user} Pass=#{pass} SSL=#{ssl}
          setg ExitOnSession false
          irb # keep console alive
        RC
        log = File.join(cfg['paths']['logs'], "msgrpc-#{Hackberry::Exec.timestamp}.log")
        cmd = "msfconsole -q -r #{rc}"
        Hackberry::Exec.tmux_run(name:'msgrpc', cmd: cmd, log_path: log)
      when 'stop'
        Hackberry::Exec.run_capture("pkill -f 'msfconsole -q -r'")
      end
    end
  end
end

Hackberry::Registry.register(Hackberry::MsfRPCD)
