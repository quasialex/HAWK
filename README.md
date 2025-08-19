# HAWK: Hackberry Assessment Web Kit

Touch‑first Ruby (Sinatra) web app that glues proven tools (Metasploit, Evilginx3, Bettercap, Wifite, Responder, Impacket, etc.). This version delivers ALL LANES:

Metasploit RPC workflows (start/stop RPC, connect, list workspaces/sessions, run exploits/handlers)

Interface autodetect (Wi‑Fi/BLE/LAN dropdowns)

Profiles (auto‑save last inputs per action)

Rogue AP suite (hostapd‑wpe, eaphammer)

Tunneling pack (ligolo‑ng, autossh)

Tail logs (live log viewer)

Status/Config (from v0.2)

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

---

### 📌 Evilginx2 (phish proxy for 2FA bypass)

```bash
# Dependencies
sudo apt install -y git make golang

# Clone repo
git clone https://github.com/kgretzky/evilginx2.git
cd evilginx2

# Build
make

# Move binary into PATH
sudo mv build/evilginx /usr/local/bin

```

Needs a public VPS + domain for real-world phishing; local use limited.

---

### 📌 pwncat-cs (post-exploitation / C2-ish tool)

---

### Build Python 3.11 from source

This is more universal, just takes \~15–20 minutes on ARM:

```bash
sudo apt install -y build-essential libssl-dev zlib1g-dev \
  libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev \
  libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev

cd /usr/src
sudo wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
sudo tar xzf Python-3.11.9.tgz
cd Python-3.11.9
sudo ./configure --enable-optimizations
sudo make -j$(nproc)
sudo make altinstall
```

This installs `python3.11` alongside 3.13 without breaking the system.

Then you can do:

```bash
pipx install --python python3.11 pwncat-csp
```
---
```bash

sudo apt update && sudo apt install -y \
  ruby-full build-essential tmux \
  wifite aircrack-ng hcxdumptool bettercap bluez bluez-hcidump blue-hydra \
  nmap responder metasploit-framework \
  impacket-scripts chisel macchanger hostapd-wpe eaphammer \
  ligolo-ng autossh
```

```bash

# optional RPC gem
sudo gem install msfrpc-client

bundle config set --local path 'vendor/bundle'
bundle install

sudo cp systemd/hawk.service /etc/systemd/system/hawk.service
sudo systemctl daemon-reload
sudo systemctl enable --now hawk
```
