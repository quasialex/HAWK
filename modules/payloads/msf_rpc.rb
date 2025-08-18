# modules/payloads/msf_rpc.rb
require 'socket'
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

begin
  require 'msfrpc-client'
rescue LoadError
  # allow app to run without the gem; module will error when used
end

module Hackberry
  class MsfRPC < ModuleBase
    def self.id; 'pay_msf_rpc'; end
    def self.category; :payloads; end
    def self.label; 'Metasploit RPC (check/connect)'; end
    def self.icon; '📦'; end

    def self.actions
      [
        { id:'check', label:'Check RPC', description:'Test tcp connectivity', inputs:[ {name:'host', label:'Host', type:'text', default:'127.0.0.1'}, {name:'port', label:'Port', type:'number', default:'55553'} ] },
        { id:'login', label:'Login & workspace list', description:'Using msfrpc-client', inputs:[ {name:'host', label:'Host', type:'text', default:'127.0.0.1'}, {name:'port', label:'Port', type:'number', default:'55553'}, {name:'user', label:'User', type:'text', default:'msf'}, {name:'pass', label:'Pass', type:'text', default:'msf'} ] }
      ]
    end

    def self.run(action_id, p, cfg)
      case action_id
      when 'check'
        host = p['host']; port = (p['port'] || '55553').to_i
        s = TCPSocket.new(host, port); s.close
        return { session: 'none', cmd: 'tcp check', log: "OK: #{host}:#{port}" }
      when 'login'
        unless defined?(Msf::RPC::Client)
          return { session:'none', cmd:'rpc login', log:'msfrpc-client gem not installed' }
        end
        c = Msf::RPC::Client.new(host: p['host'], port: (p['port']||'55553').to_i, ssl:false)
        c.login(p['user'], p['pass'])
        workspaces = c.call('db.workspaces')
        return { session:'none', cmd:'rpc login', log: workspaces.inspect }
      else
        raise 'unknown'
      end
    end
  end
end

Hackberry::Registry.register(Hackberry::MsfRPC)
