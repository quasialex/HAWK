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
          description:'Unblock → kill conflicts → airmon-ng start; fallback to iw-based monitor.',
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
        script = <<~BASH
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          IF="#{iface}"

          echo "[*] Smart Monitor on $IF @ $(date -u +'%F %T')"
          [ "$(id -u)" -eq 0 ] || { echo "[!] Run as root."; exit 126; }

          rfkill unblock all || true
          ip link set "$IF" up || true

          DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F': ' '/driver:/ {print $2}')"
          PHY="$(iw dev "$IF" info 2>/dev/null | awk '/wiphy/ {print $2}')"
          echo "[i] DRIVER=${DRV:-?}  PHY=${PHY:-?}"

          echo "[*] airmon-ng check kill"
          airmon-ng check kill || true

          # Stop any existing monitor ifaces
          PRE="$(iw dev | awk '/Interface/ {n=$2} /type monitor/ {print n}')"
          if [ -n "$PRE" ]; then
            echo "[i] Stopping existing monitor ifaces:"
            echo "$PRE" | sed 's/^/  - /'
            while read -r M; do [ -z "$M" ] && continue; airmon-ng stop "$M" || true; done <<< "$PRE"
          fi

          echo "[*] Try airmon-ng start $IF"
          if airmon-ng start "$IF"; then
            sleep 1
            MON="$(iw dev | awk '/Interface/ {n=$2} /type monitor/ {print n; exit}')"
            [ -z "$MON" ] && MON="${IF}mon"
            echo "[+] Monitor iface: $MON"
            exit 0
          fi

          echo "[!] airmon-ng failed; trying iw fallback"
          # iw fallback
          # 1) try to set existing iface to monitor
          if iw dev "$IF" set type monitor 2>/dev/null; then
            ip link set "$IF" up || true
            echo "[+] Monitor iface: $IF"
            exit 0
          fi

          # 2) create a separate monitor interface
          MON="mon0"
          iw dev "$IF" interface add "$MON" type monitor 2>/dev/null || true
          ip link set "$MON" up 2>/dev/null || true
          if iw dev | awk '/Interface/ {n=$2} /type monitor/ {print n}' | grep -q "^$MON$"; then
            echo "[+] Monitor iface: $MON"
            exit 0
          fi

          echo "[!] Monitor not supported by driver (${DRV:-unknown})"
          exit 2
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'mon_stop'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi_mon'] : p['iface']
        script = <<~BASH
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          IF="#{iface}"
          [ "$(id -u)" -eq 0 ] || { echo "[!] Run as root."; exit 126; }

          echo "[*] airmon-ng stop $IF"
          airmon-ng stop "$IF" || true

          # also try iw delete if it's a custom mon iface
          if iw dev | awk '/Interface/ {n=$2} /type monitor/ {print n}' | grep -q "^$IF$"; then
            iw dev "$IF" del || true
          fi

          echo "[*] Restarting NetworkManager & wpa_supplicant"
          systemctl restart NetworkManager 2>/dev/null || true
          systemctl restart wpa_supplicant 2>/dev/null || true
          ip a
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'psave_off'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~BASH
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          IF="#{iface}"
          [ "$(id -u)" -eq 0 ] || { echo "[!] Run as root."; exit 126; }
          iw dev "$IF" set power_save off
          iw dev "$IF" get power_save
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'restore_net'
        script = <<~BASH
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          [ "$(id -u)" -eq 0 ] || { echo "[!] Run as root."; exit 126; }
          systemctl restart NetworkManager 2>/dev/null || true
          systemctl restart wpa_supplicant 2>/dev/null || true
          nmcli general status 2>/dev/null || true
        BASH
        return Hackberry::Exec.tmux_run_script(name:'iface', content: script, log_path: log)

      when 'caps'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        script = <<~BASH
          set -e
          export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          IF="#{iface}"
          DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F': ' '/driver:/ {print $2}')"
          PHY="$(iw dev "$IF" info 2>/dev/null | awk '/wiphy/ {print $2}')"
          echo "IF: $IF  DRIVER: ${DRV:-unknown}  PHY: ${PHY:-?}"
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
