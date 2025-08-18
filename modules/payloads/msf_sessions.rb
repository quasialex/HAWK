# modules/payloads/msf_sessions.rb
require_relative '../../core/module_base'
require_relative '../../core/registry'

begin
  require 'msfrpc-client'
rescue LoadError
end

module Hackberry
  class MsfSessions < ModuleBase
    def self.id; 'pay_msf_sessions'; end
    def self.category; :payloads; end
    def self.label; 'MSF Sessions (RPC)'; end
    def self.icon; '📦'; end

    def self.actions
      [
        { id:'list', label:'List sessions', description:'Enumerate sessions via RPC',
          inputs:[ {name:'host', label:'RPC Host', type:'text', default:'127.0.0.1'}, {name:'port', label:'RPC Port', type:'number', default:'55553'}, {name:'user', label:'RPC User', type:'text', default:'msf'}, {name:'pass', label:'RPC Pass', type:'text', default:'msf'} ] }
      ]
    end

    def self.run(action_id, p, _cfg)
      unless defined?(Msf::RPC::Client)
        return { session:'none', cmd:'rpc', log:'msfrpc-client gem not installed' }
      end
      c = Msf::RPC::Client.new(host: p['host'], port: p['port'].to_i, ssl:false)
      c.login(p['user'], p['pass'])
      res = c.call('session.list')
      { session:'none', cmd:'session.list', log: res.inspect }
    end
  end
end

Hackberry::Registry.register(Hackberry::MsfSessions)
