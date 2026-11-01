# Build notes

## Plan
- Raspberry Pi 4 runs a custom portal (web app, Chromium kiosk fullscreen) over HDMI to the controller board. Starting widgets: clock, weather, calendar. Code lives in `portal/` (to be created).

## Log
- Confirmed the Mirror has a BOE panel (DV430FHM-NN5).
- Bought the CanaKit Pi 4 4GB Basic Kit (Amazon) and the e-qstore HDMI+DP+VGA controller kit (eBay).
- Found while re-reading the eBay listing: the kit needs its own 12V/4A supply, includes no inverter/power board, and the seller says the original inverter needs 24V. Upstream README recommends a Vizio mainboard instead. See PARTS.md for the checks to do first.

## To do
- [ ] Open the Mirror: check T-con connector type, power board/inverter voltage.
- [ ] Contact the seller with the cable and backlight questions.
- [ ] Order the microSD card and micro HDMI cable.
- [ ] Flash the Pi, set up kiosk mode.
- [ ] Build the portal.
