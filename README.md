# HAWK: Hackberry Assessment Web Kit — Scaffold v0.1

Touch‑first Ruby (Sinatra) web app that glues proven tools (Metasploit, Evilginx3, Bettercap, Wifite, Responder, Impacket, etc.). This version delivers ALL LANES:

Metasploit RPC workflows (start/stop RPC, connect, list workspaces/sessions, run exploits/handlers)

Interface autodetect (Wi‑Fi/BLE/LAN dropdowns)

Profiles (auto‑save last inputs per action)

Rogue AP suite (hostapd‑wpe, eaphammer)

Tunneling pack (ligolo‑ng, autossh)

Tail logs (live log viewer)

Status/Config (from v0.2)

Start: bundle install && bin/run → http://127.0.0.1:4567 (fullscreen/touch)

## File Tree

```bash
hawk/
├─ Gemfile
├─ app.rb
├─ config/
│  └─ config.yml
├─ core/
│  ├─ exec.rb           # run/tmux helpers (+list/kill)
│  ├─ module_base.rb
│  ├─ registry.rb
│  ├─ ui_helpers.rb
│  ├─ ifaces.rb         # NEW: interface discovery
│  └─ profiles.rb       # NEW: per‑action last‑used inputs
├─ modules/
│  ├─ utils/
│  │  └─ iface_tools.rb
│  ├─ wifi/
│  │  ├─ wifite.rb
│  │  ├─ hcxdump.rb
│  │  ├─ airodump.rb
│  │  ├─ bettercap_beacon.rb
│  │  ├─ wifiphisher.rb
│  │  ├─ hostapd_wpe.rb       # NEW
│  │  └─ eaphammer.rb         # NEW
│  ├─ ble/
│  │  ├─ ble_scan_bettercap.rb
│  │  └─ blue_hydra.rb
│  ├─ network/
│  │  ├─ nmap_quick.rb
│  │  ├─ responder.rb
│  │  ├─ mitm_bettercap.rb
│  │  ├─ ntlmrelayx.rb
│  │  ├─ chisel.rb
│  │  ├─ ligolo.rb            # NEW
│  │  └─ autossh.rb           # NEW
│  └─ payloads/
│     ├─ msf_handler.rb
│     ├─ pwncat.rb
│     ├─ msf_rpc.rb
│     ├─ msf_rpcd.rb          # NEW: start/stop RPC via msgrpc
│     ├─ msf_exploit.rb       # NEW: run exploit module via RPC
│     └─ msf_sessions.rb      # NEW: list sessions via RPC
├─ views/
│  ├─ layout.erb
│  ├─ index.erb
│  ├─ category.erb
│  ├─ module.erb              # supports <select> options
│  ├─ run.erb
│  ├─ status.erb
│  ├─ config.erb
│  └─ log_view.erb            # NEW
├─ public/
│  └─ app.css
├─ data/
│  ├─ logs/
│  ├─ captures/
│  └─ profiles.json           # NEW
└─ bin/
   └─ run
```

## Minimal install checklist (Kali/Hackberry)

```bash

sudo apt update && sudo apt install -y \
  ruby-full build-essential tmux \
  wifite aircrack-ng hcxdumptool bettercap bluez bluez-hcidump blue-hydra \
  nmap responder metasploit-framework evilginx pwncat-cs \
  wifiphisher impacket-scripts chisel macchanger

bundle install

bin/run → open http://127.0.0.1:4567 (fullscreen for touch).
```
