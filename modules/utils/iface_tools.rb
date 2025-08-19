# modules/utils/iface_tools.rb
require_relative '../../core/module_base'
require_relative '../../core/exec'
require_relative '../../core/registry'

module Hackberry
  class IfaceTools < ModuleBase
    def self.id      ; 'utils_iface' ; end
    def self.category; :utils        ; end
    def self.label   ; 'Interface Tools' ; end
    def self.icon    ; '🧰'          ; end

    def self.actions
      [
        { id:'mon_start',  label:'Smart Monitor Mode',
          description:'Kill conflicts → start monitor; if unsupported, passive recon.',
          inputs:[{name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'}] },

        { id:'mon_stop',   label:'Disable Monitor Mode',
          description:'airmon-ng stop + restore services',
          inputs:[{name:'iface', label:'Monitor iface', type:'text', placeholder:'wlan0mon'}] },

        { id:'psave_off',  label:'Power Save OFF',
          description:'iw set power_save off',
          inputs:[{name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'}] },

        { id:'restore_net',label:'Restore Networking',
          description:'Restart NetworkManager & wpa_supplicant', inputs:[] },

        { id:'caps',       label:'Show Capabilities',
          description:'Driver/chip + supported modes',
          inputs:[{name:'iface', label:'Wi‑Fi iface', type:'text', placeholder:'wlan0'}] }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "iface-#{Hackberry::Exec.timestamp}.log")

      case action_id
      when 'mon_start'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~'BASH'
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

          IF="<%= iface %>"
          echo "[*] HAWK Smart Monitor: $(date -u +'%F %T')"
          echo "[i] EUID=$(id -u) USER=$(whoami) PATH=$PATH"
          if [ "$(id -u)" -ne 0 ]; then
            echo "[!] Root required (airmon-ng/iw/systemctl). Run HAWK as root."
            exit 126
          fi

          rfkill unblock all || true
          ip link set "$IF" up || true

          # Capabilities
          DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F': ' '/driver:/ {print $2}')"
          PHY="$(iw dev "$IF" info 2>/dev/null | awk '/wiphy/ {print $2}')"
          echo "[i] IF=$IF  DRIVER=${DRV:-?}  PHY=${PHY:-?}"
          iw phy "$PHY" info > /tmp/hawk_iwinfo.txt 2>&1 || true

          # Stop any pre-existing monitor iface to avoid confusion
          echo "[*] Checking for existing monitor ifaces"
          PRE_MON_LIST="$(iw dev | awk '/Interface/ {name=$2} /type monitor/ {print name}')"
          if [ -n "$PRE_MON_LIST" ]; then
            echo "[i] Found pre-existing monitor ifaces:"
            echo "$PRE_MON_LIST" | sed 's/^/    - /'
            while read -r M; do
              [ -z "$M" ] && continue
              echo "[*] airmon-ng stop $M"
              airmon-ng stop "$M" || true
            done <<< "$PRE_MON_LIST"
          fi

          echo "[*] Killing conflicting processes (airmon-ng check kill)"
          airmon-ng check kill || true

          # Can this PHY do monitor mode?
          if grep -q "^[[:space:]]*\\* monitor" /tmp/hawk_iwinfo.txt; then
            echo "[+] $IF supports monitor mode (driver: ${DRV:-unknown})"
            BEFORE="$(iw dev | awk '/Interface/ {name=$2} /type monitor/ {print name}')"

            echo "[*] airmon-ng start $IF"
            if airmon-ng start "$IF"; then
              sleep 1
              AFTER="$(iw dev | awk '/Interface/ {name=$2} /type monitor/ {print name}')"
              NEW_IF=""
              # Find iface present in AFTER but not in BEFORE
              for x in $AFTER; do
                FOUND=0
                for y in $BEFORE; do [ "$x" = "$y" ] && FOUND=1 && break; done
                [ $FOUND -eq 0 ] && NEW_IF="$x"
              done
              [ -z "$NEW_IF" ] && NEW_IF="${IF}mon"

              echo "[+] Monitor enabled: $NEW_IF"
              iw dev | sed -n '/Interface/,$p' | sed -n '1,120p'
              echo "[i] Use $NEW_IF with airodump-ng/wifite/etc."
            else
              echo "[!] airmon-ng start failed (driver: ${DRV:-unknown})"
              exit 2
            fi
          else
            echo "[!] Monitor NOT supported on $IF (driver: ${DRV:-unknown})"
            echo "    Tip: AR9271/ath9k_htc or MT76xx USB adapters work well."
            echo "[*] Fallback: passive recon via 'iw scan' every 5s (12 cycles)"
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
        script = script.gsub('<%= iface %>', iface.to_s)
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'mon_stop'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi_mon'] : p['iface']
        script = <<~'BASH'
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

          IF="<%= iface %>"
          echo "[*] Disable Monitor: $(date -u +'%F %T')"
          echo "[i] EUID=$(id -u) PATH=$PATH"
          if [ "$(id -u)" -ne 0 ]; then
            echo "[!] Root required."
            exit 126
          fi

          echo "[*] airmon-ng stop $IF"
          airmon-ng stop "$IF" || true
          echo "[*] Restarting NetworkManager & wpa_supplicant"
          systemctl restart NetworkManager 2>/dev/null || true
          systemctl restart wpa_supplicant 2>/dev/null || true
          ip link show
        BASH
        script = script.gsub('<%= iface %>', iface.to_s)
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'psave_off'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~'BASH'
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          IF="<%= iface %>"
          if [ "$(id -u)" -ne 0 ]; then
            echo "[!] Root required."
            exit 126
          fi
          iw dev "$IF" set power_save off
          iw dev "$IF" get power_save
        BASH
        script = script.gsub('<%= iface %>', iface.to_s)
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'restore_net'
        script = <<~'BASH'
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          if [ "$(id -u)" -ne 0 ]; then
            echo "[!] Root required."
            exit 126
          fi
          echo "[*] Restoring network services"
          systemctl restart NetworkManager 2>/dev/null || true
          systemctl restart wpa_supplicant 2>/dev/null || true
          nmcli general status 2>/dev/null || true
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'caps'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~'BASH'
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          IF="<%= iface %>"
          DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F': ' '/driver:/ {print $2}')"
          PHY="$(iw dev "$IF" info 2>/dev/null | awk '/wiphy/ {print $2}')"
          echo "IF: $IF  DRIVER: ${DRV:-unknown}  PHY: ${PHY:-?}"
          echo "=== iw phy info ==="
          iw phy "$PHY" info 2>/dev/null || true
        BASH
        script = script.gsub('<%= iface %>', iface.to_s)
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      else
        raise 'unknown action'
      end
    end
  end
end

Hackberry::Registry.register(Hackberry::IfaceTools)
