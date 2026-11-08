#!/usr/bin/env bash
# One-time setup on the Raspberry Pi. Copy the portal over first (deploy.sh on the Mac), then on the Pi:
#   cd ~/mirror/portal && bash setup-pi.sh
#   sudo reboot
#
# Options:
#   --rotate 90|270   which way to turn the picture for the portrait panel (default 90).
#                     If the mirror shows it upside down, run again with the other one.
#   --no-spotify      skip raspotify, the Spotify speaker
#
# Safe to run again, for example to change the rotation. It expects a fresh Raspberry Pi OS
# (64-bit, with desktop) and replaces ~/.config/labwc/autostart.
set -euo pipefail

ROTATE=90
SPOTIFY=1
while [ $# -gt 0 ]; do
  case "$1" in
    --rotate) ROTATE="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --no-spotify) SPOTIFY=0; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
case "$ROTATE" in
  0|90|180|270) ;;
  *) echo "--rotate must be 0, 90, 180 or 270" >&2; exit 1 ;;
esac
if [ "$(id -u)" = 0 ]; then
  echo "Run this as your normal user, not with sudo. It asks for sudo itself." >&2
  exit 1
fi

PORTAL="$(cd "$(dirname "$0")" && pwd)"
step() { printf '\n== %s\n' "$1"; }

step "Packages"
sudo apt-get update
sudo apt-get install -y chromium wlr-randr curl python3-venv

step "Python environment"
# --system-site-packages keeps gpiozero, which comes with Raspberry Pi OS, for the presence sensor.
[ -d "$PORTAL/.venv" ] || python3 -m venv --system-site-packages "$PORTAL/.venv"
"$PORTAL/.venv/bin/pip" install -q -r "$PORTAL/requirements.txt"

step "Portal server on boot"
sudo tee /etc/systemd/system/mirror-portal.service >/dev/null <<EOF
[Unit]
Description=Mirror portal
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
WorkingDirectory=$PORTAL
ExecStart=$PORTAL/.venv/bin/python3 server.py --host 0.0.0.0 --port 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable mirror-portal
sudo systemctl restart mirror-portal

step "Desktop login, no screen blanking"
sudo raspi-config nonint do_boot_behaviour B4  # boot to the desktop, logged in
sudo raspi-config nonint do_blanking 1         # 1 = never blank the screen

step "Mirror page full screen on login"
chmod +x "$PORTAL/kiosk.sh"
mkdir -p "$HOME/.config/labwc"
# labwc, the Pi's desktop, runs this file when it starts.
echo "$PORTAL/kiosk.sh $ROTATE &" > "$HOME/.config/labwc/autostart"

if [ "$SPOTIFY" = 1 ]; then
  step "Spotify speaker (raspotify)"
  dpkg -s raspotify >/dev/null 2>&1 || curl -sL https://dtcooper.github.io/raspotify/install.sh | sh
  # Use the speaker name the portal looks for (spotify.device in config.json, "Mirror" by default).
  NAME="$("$PORTAL/.venv/bin/python3" -c 'import json, sys; print((json.load(open(sys.argv[1])).get("spotify") or {}).get("device") or "Mirror")' "$PORTAL/config.json" 2>/dev/null || echo Mirror)"
  sudo sed -i '/^#\?LIBRESPOT_NAME=/d' /etc/raspotify/conf
  echo "LIBRESPOT_NAME=\"$NAME\"" | sudo tee -a /etc/raspotify/conf >/dev/null
  sudo systemctl restart raspotify
fi

step "Done"
echo "Reboot to start the mirror page: sudo reboot"
echo "Upside down? Run: bash setup-pi.sh --rotate $([ "$ROTATE" = 90 ] && echo 270 || echo 90), then reboot."
if [ "$SPOTIFY" = 1 ]; then
  echo "Speakers: once you know the audio path, set LIBRESPOT_DEVICE in /etc/raspotify/conf"
  echo "(list the choices with: librespot --device ?) and run: sudo systemctl restart raspotify"
fi
