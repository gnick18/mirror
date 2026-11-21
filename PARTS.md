# Parts checklist: Mirror to smart mirror (BOE panel + Raspberry Pi)

Panel confirmed from its sticker: **BOE DV430FHM-NN5**, revision B9 (43"). Upstream README says it is the same panel as HV430FHB-N10.
Mirror: Model 1.1, main board "Mirror v1.1 EVT rev A08". Power board: MEGMEET MP118TX (12V + 24V outputs).
Upstream guide: https://github.com/olm3ca/mirror (Step 2 = mainboard, issue #26 = generic controller boards for this panel)

Status key: [x] ordered / have / done, [ ] still to buy or check

## Compute (Raspberry Pi)
- [x] CanaKit Raspberry Pi 4 4GB Basic Kit with PiSwitch (Amazon, ordered Oct 30, received). Check that the case and USB-C power supply are in the box.
- [x] SanDisk 64GB Ultra microSD, SDSQUJQ-064G-GZ6MA ($24.99). Ordered Nov 7, arriving Nov 8. The MacBook's SD slot can flash it using the card's microSD-to-SD adapter.
- [x] USB SD/microSD card reader. Bought Nov 8 to flash the card on a Windows PC, because the Mac's SD slot works but writing needs admin rights on a managed Mac. Anyone whose computer has no SD slot needs one (about $10).
- [x] UGREEN micro HDMI to HDMI cable, 3 ft ($6.99). Ordered Nov 7, arriving Nov 8. Pi 4 has micro HDMI ports; the controller board has a full-size HDMI input.

## Presence sensor
- [x] LD2410C 24GHz mmWave human presence sensor (EC Buying, Amazon, $11.99). Ordered Nov 7, arriving Nov 8. Pins come pre-soldered: TX, RX, OUT, GND, VCC.
- [x] 40 female-to-female Dupont jumper wires, 20 cm (California JOS, Amazon, $4.29). Ordered Nov 7, arriving Nov 8. Took 20 cm because 30 cm wouldn't arrive until Monday. Fine for bench testing. If the sensor ends up far from the Pi once mounted, get longer wires (EDGELEC sells 50 cm and 100 cm).
- Wiring plan: VCC to Pi 5V (pin 2), GND to Pi ground (pin 6), OUT to GPIO17 (pin 11). OUT is 3.3V logic, so it is safe for the Pi.
- [ ] Check on build day: does the radar see through the mirror glass? Two-way mirror coatings can be metallic. If it doesn't, mount it on the top edge of the frame or behind the old camera window.

## Display controller (keeping it, decided Nov 1)
- [x] e-qstore-2020 "HD-MI+DP+VGA LCD Controller Driver Board Monitor Kit for DV430FHM-NN0/NN1/NN5" (eBay, $35.16, option "DP+HDM+VGA board Kit"). Received by Nov 7 (shipped from Hong Kong).
  - Kit contents per listing: controller board, 5-key keypad, LVDS cable, backlight cable.
  - Checked Nov 8: board printed ME.RT2525.EB818, main chip Realtek RTD2525BR. It has a "DC IN" 12V jack, a headphone jack, a 4-pin speaker socket and an AUDIO IN jack.
  - NOT included: inverter, power board, power adapter. Board takes DC 12V/4A.
  - Seller return policy: 5 days after receipt, buyer pays return shipping (eBay page says returns through Dec 17; check which applies if needed).
- Why it's OK: panel model matches; the panel's LVDS input is a standard wire-harness socket (not FFC); the Mirror's power board already has 24V for the backlight and 12V for a controller.
- Not proven: nobody in issue #26 reported this exact DP version (they used the HDMI+DVI+VGA version, e.g. eqmarket2011 eBay item 167410340053).

## Speakers (ordered Nov 15, arriving Nov 16)
- [x] 10 pairs of JST PH 2.0 4-pin plugs with 22 AWG wire, 10 cm (Amazon, $8.99). One plug clicks into the controller's SPEAKER socket (CNA1) and carries both channels.
- [x] WAGO 221-412 lever connectors, bag of 10 (Amazon, $7.47). Four join the plug's wires to the Mirror's speaker wires. They grip 24 to 12 AWG, which is why the plugs are 22 AWG and not the common 26 AWG ones.
- [x] DOWELL wire stripper, 22 to 30 AWG (Amazon, $7.99).
- Plan: each Mirror speaker box has two drivers on two twisted pairs (orange/black and red/blue). Use one pair per side, orange/black first, and tape off red/blue. If a side sounds thin, that pair is the tweeter, so swap to red/blue. The Mirror's own speaker plugs don't fit the controller socket.

### Possibly needed later
- [x] Waysse 12V 5A power supply, 5.5x2.1mm plug ($9.99, Amazon). Ordered Nov 7, arriving Nov 8. Check the label shows center-positive before plugging it in. Lets the first power-up test run without tapping the Mirror's 12V rail. Also the fix if the Mirror's 12V rail can't run the controller (flicker / screen won't stay on). The panel alone draws 0.5A typical, 0.95A max, with a 3A inrush for about 2 ms (datasheet Table 3).
- [ ] Replacement LVDS cable, only if the kit's plug doesn't match the panel socket.
- [x] Mounting (decided Nov 8): there are no screw holes for the controller, and the panel must not be drilled. Plan: a Scotch 1 in. Indoor Mounting Square on each of the board's plastic posts, stuck to bare, cleaned metal, with electrical tape on the metal under the middle of the board. Have the squares (Ace). Still need electrical tape. Check the blue VGA socket clears the case.

### Upstream's alternative route (not using)
- Vizio TV mainboard kit (search eBay for "HV430FHB-N10") with LVDS cable, ribbon cables, power switch board, IR receiver + remote.

## Questions answered by inspection (Nov 1)
- [x] Panel LVDS input type: narrow wire-to-board socket with a metal latch, fed by a twisted-pair cable. Not an FFC.
- [x] Power board outputs: J16 (4x GND, 4x V24), CON3 (GND, GND, V24, V24), CON5 (GND, GND, V12, V12), CON2 (unlabeled in photos).
- [x] Seller's 24V warning: covered, the Mirror's own power board supplies 24V to the backlight driver.

## Check when the board arrives
- [x] Hold the kit's LVDS plug next to the panel socket: same width and latch shape, 51 pins? (Don't unplug the factory cable until it matches.) Nov 8: same width, and the visible contacts match the panel's pinout. Details in BUILD-NOTES.md.
- [x] Panel-voltage jumper on the controller (often marked 3.3V / 5V / 12V near the LVDS header) is on 12V. The panel takes 12V over the LVDS cable (datasheet pins 48 to 51). Nov 8: the cap is on the 12V pair, confirmed from the photo.
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
