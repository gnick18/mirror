#!/usr/bin/env bash
# Copy the portal from this Mac to the Pi, then restart the server there.
#   portal/deploy.sh [user@host]   (default: mirror.local, with your SSH user)
#
# config.json comes from the Mac every time. The Pi keeps its own state.json, timetable
# download (gtfs/) and Python environment. spotify_token.json is copied only the first time,
# because Spotify replaces the token as it's used, so after that the Pi's copy is the live one.
set -euo pipefail

PI="${1:-mirror.local}"
cd "$(dirname "$0")"

ssh "$PI" 'mkdir -p ~/mirror/portal'
rsync -av --delete \
  --exclude .venv --exclude __pycache__ --exclude .DS_Store \
  --exclude gtfs --exclude state.json --exclude spotify_token.json \
  ./ "$PI:mirror/portal/"

if [ -f spotify_token.json ] && ! ssh "$PI" 'test -f ~/mirror/portal/spotify_token.json'; then
  scp -p spotify_token.json "$PI:mirror/portal/"
  echo "Copied spotify_token.json. From now on only the Pi should use it."
fi

if ssh "$PI" 'systemctl is-enabled mirror-portal >/dev/null 2>&1'; then
  ssh -t "$PI" 'sudo systemctl restart mirror-portal'
  echo "Restarted. The mirror page reloads itself in a few seconds."
else
  echo "Copied. Next, set up the Pi: ssh $PI, then: cd ~/mirror/portal && bash setup-pi.sh"
fi
