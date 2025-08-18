# HAWK: Hackberry Assessment Web Kit — Scaffold v0.1

A touch-friendly Ruby web app (Sinatra) that provides big-button menus to launch Wi‑Fi, BLE, Network, Payload, and Phishing attacks using existing tools (wifite, bettercap, hcxdumptool, blue-hydra, responder, msfconsole, evilginx3, pwncat-cs, etc.).

Designed as glue: minimal typing; you select category → attack → fill minimal fields (IP/port, interface) only when needed. Long‑running tasks are spawned in tmux with logs saved to data/logs/.

Start here: bundle install && bin/run then open http://127.0.0.1:4567 (fullscreen browser for touch UI).

## File Tree

```bash
hackberry-fw/
├─ Gemfile
├─ app.rb
├─ config/
│  └─ config.yml
├─ core/
│  ├─ exec.rb
│  ├─ module_base.rb
│  ├─ registry.rb
│  └─ ui_helpers.rb
├─ modules/
│  ├─ wifi/
│  │  ├─ wifite.rb
│  │  ├─ hcxdump.rb
│  │  └─ bettercap_beacon.rb
│  ├─ ble/
│  │  ├─ ble_scan_bettercap.rb
│  │  └─ blue_hydra.rb
│  ├─ network/
│  │  ├─ nmap_quick.rb
│  │  ├─ responder.rb
│  │  └─ mitm_bettercap.rb
│  ├─ payloads/
│  │  ├─ msf_handler.rb
│  │  └─ pwncat.rb
│  └─ phishing/
│     └─ evilginx3.rb
├─ views/
│  ├─ layout.erb
│  ├─ index.erb
│  ├─ category.erb
│  ├─ module.erb
│  └─ run.erb
├─ public/
│  └─ app.css
├─ data/
│  ├─ logs/           # runtime logs
│  └─ captures/       # pcap/pmkid dumps etc
└─ bin/
   └─ run
```

## Minimal install checklist (Kali/Hackberry)

```bash

sudo apt update && sudo apt install -y ruby-full build-essential tmux \
  wifite aircrack-ng hcxdumptool bettercap bluez bluez-hcidump blue-hydra \
  nmap responder metasploit-framework evilginx pwncat-cs

# (Optional) setcap for bettercap if needed for packet injection
# sudo setcap cap_net_raw,cap_net_admin=eip $(which bettercap)

bundle install
bin/run → open http://127.0.0.1:4567 (fullscreen for touch).
```
