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

## Findings from the upstream repo's issues (olm3ca/mirror)
- Issue #26 "DV430FHM-NN5 Board for BOE": several people report a generic controller kit for this panel working, some with a Raspberry Pi running MagicMirror. One had a faulty unit (white screen) and replacing it fixed it.
- The board linked in #26 is the eqmarket2011 listing "VGA DVI LCD Controller Board Monitor Kit for DV430FHM-NN5 NN0 NN1 HD-MI" (eBay item 167410340053, about $25.40 + $6 shipping, ships from Shenzhen). It is the HDMI+DVI+VGA version. Our e-qstore order is the DP+HDMI+VGA version. Nobody in #26 reported the DP version, so it is untested, not known-bad.
- Per a commenter in #26: with this kind of board you do not need the kit's backlight output. Connect the LVDS cable and power, and the panel inverter stays on its original wiring.
- Per the same commenter, the Mirror's own power supply has 5V, 12V and 24V headers. 12V feeds the controller board, 24V is separate, and the inverter connection runs unmodified. One person's wiring, so confirm against our own power board labels.
- The upstream README still says the Mirror's T-con LVDS connector is an FFC, which is why the author needed the Vizio mainboard's LVDS cable. Whether the e-qstore cable fits is still unchecked.
- Issues not yet read: #34 (Vizio D43 LVDS cables for BOE conversion), #36 (purchase guide), #38 (BOE board to Android TV), #22, #21.

## Order status (as of Nov 1)
- e-qstore-2020 controller board: eBay shows it as awaiting shipment, so it can likely still be cancelled. Decision pending: keep it, or cancel and buy the board from #26.

## Photos to take of the Mirror (power off, unplugged)
1. Whole back of the panel with the metal case lifted.
2. Close-up of the T-con's LVDS socket (flat ribbon-style FFC with a locking tab?), with a coin or ruler for scale.
3. The power board connectors and printed labels (12V / 24V).
4. Any model-number sticker on the panel or T-con.

## Inspection of our unit (Nov 1, photos)
- Panel sticker confirms: **BOE DV430FHM-NN5**, revision B9. T-con cover stamped 2021/01/30.
- Mirror main board: "Mirror v1.1 EVT rev A08", with headers labeled MAIN POWER, DISPLAY LVDS, DISPLAY BACKLIGHT. Rear label: Mirror Model 1.1.
- Panel LVDS input (under the T-con cover, center of the panel): a narrow wire-to-board socket with a metal latch shell, fed by a twisted-pair wire LVDS cable. It is NOT a flat FFC ribbon, so the upstream README's FFC note doesn't match this socket. This looks like the standard panel-side plug that generic DV430FHM-NN5 controller kits ship with; pin count not yet counted, so confirm when the kit's cable is in hand.
- DISPLAY BACKLIGHT: a grey ribbon from the Mirror board to a white connector on a shielded board left of the T-con (likely the backlight/LED driver).
- The flat ribbons with blue ends on the right of the T-con go to the panel edge (internal panel links) and are not touched.
- Still to photograph: power board connectors and printed voltage labels.
