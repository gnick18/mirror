# Mirror portal

Full-screen page the Pi shows on the Mirror: clock, weather and calendar on a black background (black is where the mirror shows through). It is drawn on a fixed 1080x1920 portrait canvas and scaled to fit any window.

- `server.py` serves `web/` and a small API. It only uses the Python standard library, except for calendar parsing and the presence sensor.
- `web/` holds the mirror page (`index.html`, `style.css`, `app.js`) and the phone remote (`remote.html`, `remote.js`). Weather comes from Open-Meteo (free, no API key).
- `config.json` holds your settings. Copy it from `config.example.json`. It is git-ignored because calendar links are secret.

## Run it on the Mac

```
cd portal
cp config.example.json config.json   # then edit it
python3 server.py
```

Open http://localhost:8080 for the mirror and http://localhost:8080/remote for the remote. With no calendars in the config, it shows sample events. The mirror page reloads itself within a couple of seconds when a file in `web/` or the config changes.

To try the remote on your phone, start the server with `--host 0.0.0.0` and open `http://<the Mac's name>.local:8080/remote` on the same Wi-Fi.

## Settings (config.json)

- `location`: `name`, `latitude`, `longitude` for the weather.
- `units`: `"imperial"` (°F) or `"metric"` (°C).
- `clock24`, `showSeconds`: clock format.
- `calendarDays`, `maxEvents`: how far ahead the agenda looks and how many events it lists.
- `dim`: night mode. Between `from` and `to`, everything fades to `brightness` (0 to 1).
- `presence`: `gpio` is the Pi pin (BCM number) wired to the sensor's OUT, `holdSeconds` is how long the widgets stay up after you walk away. Restart the server after changing these.
- `calendars`: a list of ICS feeds, each `{ "name": "...", "url": "...", "color": "#8ab4f8" }`. The color is optional.

Getting a calendar's ICS link:
- Google Calendar: Settings, pick the calendar, "Integrate calendar", copy "Secret address in iCal format".
- Apple Calendar (iCloud): on the iPhone, open Calendar, tap Calendars, tap the (i) next to a calendar, turn on Public Calendar, then Share Link and Copy. On the Mac, Control-click the calendar in the sidebar, choose Share Calendar and tick Public Calendar. Each calendar has its own `webcal://` link, so add one entry per calendar. Only iCloud calendars can be published this way. A Google or Exchange calendar that shows up in Apple Calendar needs its own provider's link. Anyone with a public link can see that calendar's events, which is why `config.json` stays out of git.
- Outlook, including school or work Microsoft 365 accounts: sign in to Outlook on the web, open Settings (gear icon), Calendar, Shared calendars. Under "Publish a calendar", pick the calendar, choose "Can view titles and locations", click Publish and copy the ICS link (not the HTML one). If that section is missing or only offers "Can view when I'm busy", the school's IT has limited publishing for the account. Feeds with Windows time zone names like "Central Standard Time" parse correctly (tested Nov 7).

Calendars need two Python packages. Install them in a virtual environment:

```
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python server.py
```

## Phone remote and presence sensor

The remote (`/remote`, add it to your phone's home screen) has three display modes:
- Auto: widgets fade in when the sensor sees someone and fade to black, which is plain mirror, after `holdSeconds` with nobody there.
- Always on: widgets always show.
- Mirror only: widgets stay hidden.

It can also switch single widgets off and reload the mirror page. Mode and widget choices are saved in `state.json` (git-ignored) and survive restarts. Anyone on the same Wi-Fi can open the remote.

Until the sensor is wired, or when running on the Mac, the "Pretend someone's here" switch stands in for it. The sensor is an LD2410C: VCC to 5V (pin 2), GND to ground (pin 6), OUT to GPIO17 (pin 11). It is read using gpiozero, which comes with Raspberry Pi OS, so on the Pi create the virtual environment with `python3 -m venv --system-site-packages .venv` to keep access to it.

## Setting up the Pi

1. Flash the microSD from the Mac using Raspberry Pi Imager. Choose Raspberry Pi 4 and Raspberry Pi OS (64-bit), the version with desktop, because the kiosk needs it. In the customisation step:
   - hostname `mirror`
   - your username and password
   - Wi-Fi name and password, and your time zone
   - turn on SSH with public-key authentication, using the Mac's key (`~/.ssh/id_rsa.pub`)
2. Boot the Pi on any TV first, to check the Pi and the micro HDMI cable before they go into the Mirror. Use HDMI0, the port next to USB-C power.
3. Once `ssh <user>@mirror.local` works from the Mac, the rest (portrait rotation, Chromium kiosk, starting the server on boot, no screen blanking) can be done over SSH.
