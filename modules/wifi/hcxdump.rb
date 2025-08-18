# modules/wifi/hcxdump.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class HcxDump < ModuleBase
    def self.id; 'wifi_hcxdump'; end
    def self.category; :wifi; end
    def self.label; 'hcxdumptool/PMKID'; end
    def self.icon; '📡'; end

    def self.actions
      [
        {
          id: 'pmkid', label: 'PMKID Dump',
          description: 'Capture PMKIDs quickly for offline cracking',
          inputs: [
            {name:'iface', label:'Monitor iface', type:'text', placeholder:'wlan0mon'},
            {name:'chan', label:'Channel (opt)', type:'text', placeholder:'1,6,11'},
            {name:'timeout', label:'Timeout (min)', type:'number', default:'5'}
          ]
        }
      ]
    end

    def self.run(action_id, p, cfg)
      iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi_mon'] : p['iface']
      out = File.join(cfg['paths']['captures'], "pmkid-#{Hackberry::Exec.timestamp}.pcapng")
      log = File.join(cfg['paths']['logs'], "hcxdump-#{Hackberry::Exec.timestamp}.log")
      t = (p['timeout'] || '5').to_i
      chan = p['chan']
      chopt = chan && !chan.empty? ? "-c #{chan}" : ''
      cmd = "timeout #{t}m hcxdumptool -i #{iface} #{chopt} -o #{out} --enable_status=1"
      Hackberry::Exec.tmux_run(name:'hcxdump', cmd: cmd, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::HcxDump)
