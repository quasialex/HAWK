# modules/utils/iface_tools.rb
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
        { id:'mon_start',  label:'Smart Monitor Mode', description:'Try monitor mode; if unsupported, fall back to recon and explain', inputs:[{name:'iface', label:'Wi-Fi iface', type:'text', placeholder:'wlan0'}] },
        { id:'mon_stop',   label:'Disable Monitor Mode', description:'airmon-ng stop', inputs:[{name:'iface', label:'Monitor iface', type:'text', placeholder:'wlan0mon'}] },
        { id:'psave_off',  label:'Power Save OFF', description:'iw set power_save off', inputs:[{name:'iface', label:'Wi-Fi iface', type:'text', placeholder:'wlan0'}] },
        { id:'restore_net',label:'Restore Networking', description:'Restart NetworkManager & wpa_supplicant', inputs:[] },
        { id:'caps',       label:'Show Capabilities', description:'Print driver/chip + supported modes', inputs:[{name:'iface', label:'Wi-Fi iface', type:'text', placeholder:'wlan0'}] }
      ]
    end

    def self.run(action_id, p, cfg)
      log = File.join(cfg['paths']['logs'], "iface-#{Hackberry::Exec.timestamp}.log")
      case action_id
      when 'mon_start'
        iface = p['iface'].to_s.empty? ? cfg['interfaces']['wifi'] : p['iface']
        cmd = %Q{bash -lc '
set -e
IF="#{iface}"
echo "[*] HAWK smart monitor: checking $IF"
DRV="$(ethtool -i "$IF" 2>/dev/null | awk -F": " "/driver:/ {print $2}")"
PHY="$(iw dev "$IF" info 2>/dev/null | awk "/wiphy/ {print $2}")"
iw phy "$PHY" info > /tmp/hawk_iwinfo.txt 2>&1 || true
if grep -q "^\\s\\* monitor" /tmp/hawk_iwinfo.txt; then
  echo "[+] $IF supports monitor (driver: ${DRV:-unknown})"
  echo "[*] Killing interfering procs (airmon-ng check kill)"
  airmon-ng check kill || true
  echo "[*] Trying: airmon-ng start $IF"
  if airmon-ng start "$IF"; then
    echo "[+] airmon-ng start
