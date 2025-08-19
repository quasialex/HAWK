# modules/ble/recon.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class BLERecon < ModuleBase
    def self.id      ; 'ble_recon' ; end
    def self.category; :ble        ; end
    def self.label   ; 'BLE Recon' ; end
    def self.icon    ; '🧿'        ; end

    def self.actions
      [
        { id:'scan', label:'BLE Scan', description:'btmon + bluetoothctl scan on',
          inputs:[ {name:'iface', label:'HCI device', type:'text', placeholder:'hci0'} ] }
      ]
    end

    def self.run(action_id, p, cfg)
      return unless action_id == 'scan'
      hci = p['iface'].to_s.strip
      hci = 'hci0' if hci.empty?

      base = File.join(cfg['paths']['logs'], "ble-#{Hackberry::Exec.timestamp}")
      log  = "#{base}.log"

      # Use btmon for HCI traffic + bluetoothctl for friendly discovery
      script = <<~BASH
        set -e
        export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        HCI="#{hci}"
        echo "[*] BLE Recon on $HCI — $(date -u +'%F %T')"
        if ! command -v btmon >/dev/null 2>&1; then
          echo "[!] btmon not found (bluez). Install bluez tools."
          exit 127
        fi
        hciconfig "$HCI" up || true
        ( btmon ) &
        M=$!
        sleep 1
        bluetoothctl --timeout 30 -- "#{hci}" scan on || bluetoothctl --timeout 30 scan on || true
        kill $M || true
        echo "[*] BLE recon done."
      BASH

      Hackberry::Exec.tmux_run_script(name:'ble', content: script, log_path: log)
    end
  end
end

Hackberry::Registry.register(Hackberry::BLERecon)
