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

## Power board (photos, Nov 1)
- MEGMEET PCB MP118TX (transformer EE4015-12V-24V). Outputs printed on the board edge:
  - J16/CON4 (8-pin): 4x GND, 4x V24
  - CON3 (4-pin): GND, GND, V24, V24
  - CON5 (4-pin): GND, GND, V12, V12 (black + orange wires, apparently to the Mirror board's MAIN POWER)
  - CON2: multi-pin, mostly unpopulated, labels not readable in the photo
- So the Mirror already has both rails: 24V for the backlight/LED driver (stays wired as-is) and 12V for a controller board. No extra power board needed; this answers the seller's 24V warning.
- Unknown: the 12V rail's current rating, and whether it can feed the Mirror board and the new controller (needs 12V/4A) at the same time. Fallback: a separate 12V/4A adapter.
- Added Nov 7, inferred from the datasheet: the panel's 12V comes in over the LVDS cable (pins 48 to 51), so the Mirror board was already feeding the panel (up to 0.95 A) from this 12V rail. After the swap the controller takes over that load, so the extra draw on the rail should be roughly the controller board itself. This makes the internal rail more likely to be enough, but it is not measured.
- Backlight control: today the Mirror board drives the LED driver over the grey DISPLAY BACKLIGHT ribbon. Plan per upstream + issue #26: leave that in place (keep the Mirror board powered, factory-reset mode so the backlight doesn't time out), and only move the panel LVDS input to the new controller.

## Decision (Nov 1)
- Keep the e-qstore DP+HDMI+VGA board. Panel match confirmed, LVDS socket is the standard wire-harness type, and 12V/24V rails exist. Remaining risks: DP version untested by others; confirm the LVDS plug's pin count matches when the kit arrives.

## To do (updated Nov 1, replaces the list above)
- [x] Open the Mirror: check T-con connector type, power board voltages. Done, see inspection and power board notes.
- [x] Contact the seller about cable fit and backlight: no longer needed.
- [x] Order the microSD card and micro HDMI cable. Ordered Nov 7, arriving Nov 8. Controller board and Pi kit are in hand.
- [ ] Decide how the controller gets 12V for the first test (separate adapter, or the Mirror's 12V rail). See build day steps.
- [ ] When the controller arrives: compare the kit's LVDS plug to the panel socket before unplugging anything.
- [ ] Put the Mirror in factory-reset mode, move the panel LVDS cable to the new controller, power it from 12V, connect the Pi over HDMI, test.
- [ ] Flash the Pi, set up kiosk mode.
- [ ] Build the portal. First version started Nov 7 in `portal/`.

## Panel facts from the datasheet (datasheets/DV430FHM-NN0-BOE.pdf, same panel family as our NN5)
- Panel input CN1 is a 51-pin LVDS connector, 2 channels, 8-bit (Table 5).
- The panel's logic power comes in over the same LVDS cable: +12V on pins 48 to 51 (10.8 to 13.2 V, 0.5 A typical, 0.95 A max, 3 A inrush for about 2 ms). So the controller board has to put 12V on the LVDS cable, not 5V or 3.3V.
- Pin 7 (SELLVDS) picks the LVDS format: high = JEIDA, low or open = VESA. If colors look wrong, the board's LVDS format setting is the first thing to check.
- The panel has a built-in test pattern (white, black, red, green, blue, 2 s each). Panels like this usually play it when they have power but no LVDS clock. Seeing it means the 12V is reaching the panel and the video data isn't.
- The LED backlight converter runs on 24V (2.67 A typical, 64 W). It stays on the Mirror's own power board.

## Build day steps (written Nov 7)
Safety rule for the whole build: only plug or unplug anything with the Mirror unplugged from the wall, and keep hands off the power board (mains voltage) while it is plugged in.

Before opening
1. Factory-reset the Mirror (hold the blue button) and confirm it comes up on the setup screen, so the backlight won't time out.
2. Unplug from the wall and wait 10 minutes for the power board's capacitors to drain. Lay it face down on a blanket, remove the 4 back screws and lift the metal case.

Check the kit before changing anything
3. Photograph the controller board (both sides), its jumpers, its power input and both ends of the LVDS cable.
4. Kit LVDS plug vs. panel socket: 51 pins, same width, same latch? If not, stop (see troubleshooting).
5. Panel-voltage jumper on the controller must be on 12V. A wrong setting can damage the panel's T-con. If there is no jumper or the marking is unclear, stop and check the listing or ask the seller.
6. Note the board's power input: DC jack size and/or a 12V header.

Swap the LVDS cable
7. Unplug the factory LVDS cable at both ends (panel socket and the Mirror board's DISPLAY LVDS header) and keep it. Upstream did the same and the Mirror board still ran the backlight.
8. Plug the kit cable into the panel socket in the same orientation as the factory plug, fully seated with the latch closed. Plug the other end into the controller.
9. Leave the kit's backlight cable unconnected. Leave the grey DISPLAY BACKLIGHT ribbon and the Mirror board's power wiring as they are.
10. Connect the keypad. Rest the controller on cardboard, not on the metal case.

First light
11. 12V to the controller, one of:
    - Option A (simplest first test): a 12V adapter, 3A or more, into the board's DC jack.
    - Option B: the Mirror's 12V rail (CON5 or a free 12V header). Needs a pigtail or splice, so photograph CON5 and CON2 first and check which pins are free.
12. Video source: the MacBook's HDMI port with a regular HDMI cable, or the Pi on HDMI0 (the micro HDMI port next to the USB-C power port).
13. Plug in the Mirror, then power the controller. Expect the backlight, then the controller's logo or "No signal", then the picture. Use the keypad to pick the HDMI input if needed. The picture will be sideways until the Pi is set to portrait.
14. Leave it running for an hour with the back open. Check that nothing gets hot and the backlight stays on.

After it works
15. Mount the controller and Pi (standoffs or sticky mounts, Kapton tape under the boards), route HDMI, USB and power out through the old ethernet opening, close up.

## If something goes wrong on first power-up
- Panel cycles white, black, red, green, blue: the panel has 12V but no video data. Check the LVDS plug is seated at both ends and the input source on the keypad menu.
- Picture shows but colors are wrong or noisy: LVDS format (JEIDA vs VESA) or bit depth setting on the controller is off. Check the board's jumpers or menu.
- Screen flickers, cuts out or won't stay on: likely not enough 12V current. Try a separate 12V 4A wall adapter.
- LVDS plug doesn't match the socket: need a matching LVDS cable, or return the kit.
- White screen / no image, menu buttons do nothing: possibly a faulty board (one report in issue #26, fixed by a replacement unit). Return or exchange.
- Backlight turns off after a while: put the Mirror back into factory-reset/setup mode (upstream README).
