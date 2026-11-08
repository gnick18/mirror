#!/usr/bin/env bash
# Started by the Pi's desktop at login (setup-pi.sh puts it in ~/.config/labwc/autostart).
# Turns the picture for the portrait panel, waits for the portal server, then keeps Chromium
# full screen on the mirror page.
#   kiosk.sh [rotation]   0, 90, 180 or 270 (default 90)
ROTATE="${1:-90}"
URL="http://localhost:8080"
PREFS="$HOME/.config/chromium/Default/Preferences"

# The first connected HDMI output, usually HDMI-A-1 (the micro HDMI port next to USB-C power).
OUTPUT="$(wlr-randr | awk '/^HDMI/ { print $1; exit }')"
[ -n "$OUTPUT" ] && wlr-randr --output "$OUTPUT" --transform "$ROTATE"

until curl -fs "$URL/api/state" >/dev/null; do sleep 1; done

while true; do
  # After a power cut Chromium offers to restore the last pages. Mark the last run as a clean exit so it doesn't.
  [ -f "$PREFS" ] && sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]*"/"exit_type":"Normal"/' "$PREFS"
  chromium --kiosk --noerrdialogs --disable-infobars --no-first-run \
    --password-store=basic --disable-features=Translate --check-for-update-interval=31536000 \
    --overscroll-history-navigation=0 --disable-pinch "$URL"
  sleep 2  # start it again if it ever closes or crashes
done
