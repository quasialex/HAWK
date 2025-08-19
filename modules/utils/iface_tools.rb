require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class IfaceTools < ModuleBase
    def self.id; 'utils_iface'; end
    def self.category; :utils; end
    def self.label; 'Interface Tools'; end
    def self.icon; '🧰'; end

    def self.actions
      [
        { id:'mon_start',  label:'Smart Monitor Mode', description:'Try monitor; if unsupported, fall back to recon and explain.',
          inputs:[{name:'iface', label:'Wi-Fi iface', type:'text', placeholder:'wlan0'}] },
        { id:'mon_stop',   label:'Disable Monitor Mode', description:'airmon-ng stop',
          inputs:[{name:'iface', label:'Monitor iface', type:'text', placeholder:'wlan0mon'}] },
        { id:'psave_off',  label:'Power Save OFF', description:'iw set power_save off',
          inputs:[{name:'iface', label:'Wi-Fi iface', type:'text', placeholder:'wlan0'}] },
        { id:'restore_net',label:'Restore Networking', description:'Restart NetworkManager & wpa_supplicant', inputs:[] },
        { id:'caps',       label:'Show Capabilities', description:'Driver/chip + supported modes',
          inputs:[{name:'iface', label:'Wi-Fi iface', type:'text', placeholder:'wlan0'}] }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "iface-#{Hackberry::Exec.timestamp}.log")

      case action_id
      when 'mon_start'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~BASH
          set -e
          IF="#{iface}"
          echo "[*] HAWK smart monitor: checking $IF"

          DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F": " "/driver:/ {print $2}")"
          PHY="$(iw dev "$IF" info 2>/dev/null | awk "/wiphy/ {print $2}")"

          if [ -z "$PHY" ]; then
            echo "[!] Could not resolve PHY for $IF. Is the interface up? (ip link set $IF up)"
            exit 1
          fi

          iw phy "$PHY" info > /tmp/hawk_iwinfo.txt 2>&1 || true
          if grep -q "^\\s\\* monitor" /tmp/hawk_iwinfo.txt; then
            echo "[+] $IF supports monitor (driver: ${DRV:-unknown})"
            echo "[*] Killing interfering procs (airmon-ng check kill)"
            airmon-ng check kill || true
            echo "[*] Trying: airmon-ng start $IF"
            if airmon-ng start "$IF"; then
              MON_IF="$(iw dev | awk '/type monitor/{print $2; exit}')"
              echo "[+] Monitor enabled: ${MON_IF:-${IF}mon}"
              iw dev | sed -n '/Interface/,$p' | sed -n '1,50p'
              echo "[i] You can now run airodump/wifite/etc on ${MON_IF:-${IF}mon}"
            else
              echo "[!] airmon-ng start failed unexpectedly."
              exit 2
            fi
          else
            echo "[!] Monitor mode NOT supported by $IF (driver: ${DRV:-unknown})."
            echo "    Common on brcmfmac/Broadcom 434xx."
            echo "    Options: external USB (AR9271/ath9k_htc, MT76xx) or device-specific nexmon."
            echo ""
            echo "[*] Fallback: passive recon without monitor (iw scan every 5s, 12 cycles)."
            for i in $(seq 1 12); do
              echo "--- SCAN #$i ---"
              iw dev "$IF" scan 2>/dev/null | \
                awk '/^BSS /{mac=$2}
                     /SSID:/{ssid=$0; sub("SSID: ","",ssid)}
                     /signal:/{sig=$2}
                     /freq:/{f=$2}
                     /^\\t$/{if (mac!="" && ssid!=""){printf "BSS %s  sig %s dBm  freq %s  ssid %s\\n", mac, sig, f, ssid; mac=""; ssid=""; sig=""; f=""}}'
              sleep 5
            done
            echo "[*] Fallback recon ended."
          fi
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'mon_stop'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi_mon'] : p['iface']
        script = <<~BASH
          set -e
          IF="#{iface}"
          echo "[*] Disabling monitor on $IF"
          airmon-ng stop "$IF" || true
          echo "[*] Restarting NetworkManager/wpa_supplicant"
          systemctl restart NetworkManager 2>/dev/null || true
          systemctl restart wpa_supplicant 2>/dev/null || true
          ip link show
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'psave_off'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        return Hackberry::Exec.tmux_run_script(
          name:'iface',
          content: %(iw dev "#{iface}" set power_save off; iw dev "#{iface}" get power_save),
          log_path: log
        )

      when 'restore_net'
        script = <<~BASH
          echo "[*] Restoring network services"
          systemctl restart NetworkManager 2>/dev/null || true
          systemctl restart wpa_supplicant 2>/dev/null || true
          nmcli general status 2>/dev/null || true
          ip a
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'caps'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~BASH
          IF="#{iface}"
          DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F": " "/driver:/ {print $2}")"
          PHY="$(iw dev "$IF" info 2>/dev/null | awk "/wiphy/ {print $2}")"
          echo "IF: $IF  DRIVER: ${DRV:-unknown}  PHY: ${PHY:-?}"
          echo "=== iw phy info ==="
          iw phy "$PHY" info 2>/dev/null || true
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      else
        raise 'unknown action'
      end
    end
  end
end

Hackberry::Registry.register(Hackberry::IfaceTools)
