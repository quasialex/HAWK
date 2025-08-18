# modules/network/chisel.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Chisel < ModuleBase
    def self.id; 'net_chisel'; end
    def self.category; :network; end
    def self.label; 'Chisel (Tunnel)'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        {
          id:'server', label:'Server (listen)', description:'chisel server -p <port>',
          inputs:[ {name:'port', label:'Port', type:'number', default:'8000'} ]
        },
        {
          id:'client_rport', label:'Client RPortFwd', description:'client to server; r:LOCAL:REMOTE',
          inputs:[
            {name:'srv', label:'Server host:port', type:'text', placeholder:'1.2.3.4:8000'},
            {name:'r', label:'R spec', type:'text', placeholder:'R:1337:127.0.0.1:3389'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "chisel-#{Hackberry::Exec.timestamp}.log")
      case action_id
      when 'server'
        port = (p['port'] || '8000').to_i
        cmd = "chisel server -p #{port}"
      when 'client_rport'
        srv = p['srv'] || '127.0.0.1:8000'
        spec = p['r'] || 'R:1337:127.0.0.1:3389'
        cmd = "chisel client #{srv} #{spec}"
      else
        raise 'unknown'
      end
      Hackberry::Exec.tmux_run(name:'chisel', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Chisel)
