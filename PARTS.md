# Parts checklist: Mirror to smart mirror (BOE panel + Raspberry Pi)

Panel confirmed: **BOE DV430FHM-NN5** (43"), per the upstream README the same panel as HV430FHB-N10.
Upstream guide: https://github.com/olm3ca/mirror (Step 2 = mainboard)

Status key: [x] ordered / have, [ ] still to buy or check

## Compute (Raspberry Pi)
- [x] CanaKit Raspberry Pi 4 4GB Basic Kit with PiSwitch (Amazon, ordered Oct 30). Kit should include case and USB-C power supply; verify when it arrives.
- [ ] SanDisk 64GB Ultra microSD, SDSQUJQ-064G-GZ6MA ($24.99). In Amazon cart, not yet ordered.
- [ ] UGREEN micro HDMI to HDMI cable, 3 ft ($6.99). In Amazon cart, not yet ordered. Pi 4 has micro HDMI ports; the controller board has a full-size HDMI input.

## Display controller (DIFFERS from the upstream README)
- [x] e-qstore-2020 "HD-MI+DP+VGA LCD Controller Driver Board Monitor Kit for DV430FHM-NN0/NN1/NN5" (eBay, $35.16, option "DP+HDM+VGA board Kit").
  - Kit contents per listing: controller board, 5-key keypad, LVDS cable, backlight cable.
  - NOT included: inverter, power board, power adapter. Board takes DC 12V/4A.
  - No Wi-Fi, IR receiver or power-switch board (the upstream README's steps use those).
  - Ships from Hong Kong, 7-30 working days per seller (eBay estimated Nov 10-17). Customs/import taxes are the buyer's responsibility.
  - Seller return policy: 5 days after receipt, buyer pays return shipping. eBay page said returns accepted through Dec 17; confirm which applies.

### Upstream's recommended route (fallback if the e-qstore board fails)
- [ ] Vizio TV mainboard kit found by searching eBay for "HV430FHB-N10", ideally with: LVDS cable, ribbon cables, power switch board, IR receiver + remote. Skip the kit's own TCON board; the Mirror's stays.
- [ ] Power cord for the mainboard, if not included.

## Open questions to settle BEFORE the board arrives (open the Mirror)
- [ ] Is the Mirror's T-con LVDS connector an FFC? Upstream says it is, which is why the author needed the Vizio board's LVDS cable. Does the e-qstore LVDS cable fit?
- [ ] What voltage does the Mirror's power board / inverter output? Seller says the original inverter needs 24V and the kit includes no power board.
- [ ] Where will the board's 12V/4A come from (spare adapter, or tapped from the Mirror's power supply)?
- [ ] Message e-qstore-2020 to confirm cable fit and backlight compatibility.

## Tools
- [ ] Phillips screwdriver
- [ ] TR10 and TR6 Torx drivers
- [ ] Wire cutters
- [ ] Compatible screws to mount the board to the panel

## Already in the Mirror (no purchase)
- TCON board, inverter and power supply, speakers, scalar board (keeps the backlight working), factory-reset button (hold first so the backlight doesn't time out)

## Not part of this build
- Amazon Basics USB-C to USB-C 2-pack (in cart; for personal use)
