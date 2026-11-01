# Parts checklist: Mirror to smart mirror (BOE panel + Raspberry Pi)

Panel confirmed from its sticker: **BOE DV430FHM-NN5**, revision B9 (43"). Upstream README says it is the same panel as HV430FHB-N10.
Mirror: Model 1.1, main board "Mirror v1.1 EVT rev A08". Power board: MEGMEET MP118TX (12V + 24V outputs).
Upstream guide: https://github.com/olm3ca/mirror (Step 2 = mainboard, issue #26 = generic controller boards for this panel)

Status key: [x] ordered / have / done, [ ] still to buy or check

## Compute (Raspberry Pi)
- [x] CanaKit Raspberry Pi 4 4GB Basic Kit with PiSwitch (Amazon, ordered Oct 30). Kit should include case and USB-C power supply; verify when it arrives.
- [ ] SanDisk 64GB Ultra microSD, SDSQUJQ-064G-GZ6MA ($24.99). In Amazon cart, not yet ordered.
- [ ] UGREEN micro HDMI to HDMI cable, 3 ft ($6.99). In Amazon cart, not yet ordered. Pi 4 has micro HDMI ports; the controller board has a full-size HDMI input.

## Display controller (keeping it, decided Nov 1)
- [x] e-qstore-2020 "HD-MI+DP+VGA LCD Controller Driver Board Monitor Kit for DV430FHM-NN0/NN1/NN5" (eBay, $35.16, option "DP+HDM+VGA board Kit"). Awaiting shipment as of Nov 1; ships from Hong Kong.
  - Kit contents per listing: controller board, 5-key keypad, LVDS cable, backlight cable.
  - NOT included: inverter, power board, power adapter. Board takes DC 12V/4A.
  - Seller return policy: 5 days after receipt, buyer pays return shipping (eBay page says returns through Dec 17; check which applies if needed).
- Why it's OK: panel model matches; the panel's LVDS input is a standard wire-harness socket (not FFC); the Mirror's power board already has 24V for the backlight and 12V for a controller.
- Not proven: nobody in issue #26 reported this exact DP version (they used the HDMI+DVI+VGA version, e.g. eqmarket2011 eBay item 167410340053).

### Possibly needed later
- [ ] 12V 4A DC wall adapter, only if the Mirror's 12V rail can't run the controller (flicker / screen won't stay on).
- [ ] Replacement LVDS cable, only if the kit's plug doesn't match the panel socket.

### Upstream's alternative route (not using)
- Vizio TV mainboard kit (search eBay for "HV430FHB-N10") with LVDS cable, ribbon cables, power switch board, IR receiver + remote.

## Questions answered by inspection (Nov 1)
- [x] Panel LVDS input type: narrow wire-to-board socket with a metal latch, fed by a twisted-pair cable. Not an FFC.
- [x] Power board outputs: J16 (4x GND, 4x V24), CON3 (GND, GND, V24, V24), CON5 (GND, GND, V12, V12), CON2 (unlabeled in photos).
- [x] Seller's 24V warning: covered, the Mirror's own power board supplies 24V to the backlight driver.

## Check when the board arrives
- [ ] Hold the kit's LVDS plug next to the panel socket: same width and latch shape? (Don't unplug the factory cable until it matches.)
- [ ] 12V rail current: does it handle the Mirror board + controller at once?

## Tools
- [ ] Phillips screwdriver
- [ ] TR10 and TR6 Torx drivers
- [ ] Wire cutters
- [ ] Compatible screws to mount the board

## Already in the Mirror (no purchase)
- T-con, backlight/LED driver board, power board, speakers, Mirror main board (keeps running the backlight), factory-reset button (hold first so the backlight doesn't time out)

## Not part of this build
- Amazon Basics USB-C to USB-C 2-pack (in cart; for personal use)
