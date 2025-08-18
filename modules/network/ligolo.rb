# modules/network/ligolo.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class Ligolo < ModuleBase
    def self.id; 'net_ligolo'; end
    def self.category; :network; end
    def self.label; 'Ligolo‑ng'; end
    def self.icon; '🌐'; end

    def self.actions
      [
        { id:'server', label:'Server listen', description:'Start proxy server', inputs:[ {name:'port', label:'Port', type:'number', default:'11601'} ] },
        { id:'agent',  label:'Agent connect', description:'Connect to server', inputs:[ {name:'srv', label:'Server host:port', type:'text', default:'1.2.3.4:11601'}, {name:'auto', label:'Auto route (y/n)', type:'text', default:'y'} ] }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "ligolo-#{Hackberry::Exec.timestamp}.log")
      case action_id
      when 'server'
        port = (p['port'] || '11601').to_i
        cmd = "ligolo-ng server -listen 0.0.0.0:#{port} -selfcert"
      when 'agent'
        srv = p['srv']
        auto = (p['auto']||'y').downcase.start_with?('y')
        cmd = "ligolo-ng agent -connect #{srv} -ignore-cert"
        cmd += " -auto" if auto
      else
        raise 'unknown'
      end
      Hackberry::Exec.tmux_run(name:'ligolo', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::Ligolo)
