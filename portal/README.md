# Mirror portal

Full-screen page the Pi shows on the Mirror: clock, weather, bus times, Spotify and today's calendar on a black background (black is where the mirror shows through). It is drawn on a fixed 1080x1920 portrait canvas and scaled to fit any window.

- `server.py` serves `web/` and a small API. It only uses the Python standard library, except for calendar parsing, live bus times and the presence sensor.
- `bus.py` works out the next buses from Metro Transit's timetable and live feed. `spotify.py` talks to the Spotify Web API and handles the one-time login.
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
- `maxEvents`: the most events the calendar lists. It only shows what's left of today, and hides when there's nothing.
- `dim`: night mode. Between `from` and `to`, everything fades to `brightness` (0 to 1).
- `presence`: `gpio` is the Pi pin (BCM number) wired to the sensor's OUT, `holdSeconds` is how long the widgets stay up after you walk away. Restart the server after changing these.
- `bus`: see Bus times below.
- `spotify`: `clientId` of your Spotify app, and `device`, the name of the mirror's Spotify speaker. See Spotify below.
- `calendars`: a list of ICS feeds, each `{ "name": "...", "url": "...", "color": "#8ab4f8" }`. The color is optional.

Getting a calendar's ICS link:
- Google Calendar: Settings, pick the calendar, "Integrate calendar", copy "Secret address in iCal format".
- Apple Calendar (iCloud): on the iPhone, open Calendar, tap Calendars, tap the (i) next to a calendar, turn on Public Calendar, then Share Link and Copy. On the Mac, Control-click the calendar in the sidebar, choose Share Calendar and tick Public Calendar. Each calendar has its own `webcal://` link, so add one entry per calendar. Only iCloud calendars can be published this way. A Google or Exchange calendar that shows up in Apple Calendar needs its own provider's link. Anyone with a public link can see that calendar's events, which is why `config.json` stays out of git.
- Outlook, including school or work Microsoft 365 accounts: sign in to Outlook on the web, open Settings (gear icon), Calendar, Shared calendars. Under "Publish a calendar", pick the calendar, choose "Can view titles and locations", click Publish and copy the ICS link (not the HTML one). If that section is missing or only offers "Can view when I'm busy", the school's IT has limited publishing for the account. Feeds with Windows time zone names like "Central Standard Time" parse correctly (tested Nov 7).

Calendars and live bus times need a few Python packages. Install them in a virtual environment:

```
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python server.py
```

## Bus times

The bus card lists, one row per route, when to leave home for the next bus that gets you to your destination, the next two after it, and when you would arrive. It uses Metro Transit's timetable (downloaded to `gtfs/` once a day, git-ignored) and its live feed. A small signal icon marks buses that are being tracked. Dimmer rows are timetable times. Live times are only fetched while the widgets are showing, so nothing is downloaded while nobody is at the mirror. Data provided under license granted by City of Madison, WI, Metro Transit.

Settings under `bus`:
- `from`: the stops you walk to, each `{ "stop": "10038", "walk": 5 }`. `stop` is the number on the bus stop sign (also in the Metro app), and `walk` is minutes from your door. An optional `name` replaces the stop's long name on the mirror.
- `to`: the stops you get off at, with `walk` as minutes from the stop to where you are going.
- `routes`: optional, only show these routes, e.g. `["28", "A"]`.
- `count`: how many routes to list (default 4). `hours`: optional, e.g. `{ "from": "06:00", "to": "11:00" }`, to only show the card in the morning.
- `title`: the card's heading.

Only buses that go straight from a `from` stop to a `to` stop are listed, not trips with a transfer.

## Spotify

The now-playing card shows what is playing on your Spotify account on any device, and the remote gets play, pause, skip and "Play on the mirror's speakers". It needs a free Spotify developer app of your own. Since February 2026 these apps only work while the app owner has Premium.

1. Go to developer.spotify.com/dashboard, log in with your Spotify account and create an app. Any name works. Add the redirect URI `http://127.0.0.1:8888/callback` exactly, and tick Web API.
2. Copy the app's Client ID into `config.json` under `"spotify": { "clientId": "..." }`. It isn't a secret, and no client secret is needed.
3. Log in once on the Mac: `.venv/bin/python spotify.py login`. It opens Spotify in the browser and saves `spotify_token.json` (git-ignored).
4. For the Pi, copy that file over: `scp spotify_token.json <user>@mirror.local:~/mirror/portal/`. Spotify may replace the login token when it is used, so after copying, only use it on the Pi. To use the Mac again, log in again there.

"Play on the mirror's speakers" moves playback to a Spotify Connect speaker named `device` (default "Mirror"), which will be raspotify running on the Pi.

## Phone remote and presence sensor

The remote (`/remote`, add it to your phone's home screen) has three display modes:
- Auto: widgets fade in when the sensor sees someone and fade to black, which is plain mirror, after `holdSeconds` with nobody there.
- Always on: widgets always show.
- Mirror only: widgets stay hidden.

It can also control Spotify, switch single widgets off and reload the mirror page. Mode and widget choices are saved in `state.json` (git-ignored) and survive restarts. Anyone on the same Wi-Fi can open the remote.

There is also a native iPhone app, McQueen Mirror, in `ios/`. It has the same controls plus home-screen and Lock Screen widgets and a Control Center toggle. See `ios/README.md`.

Until the sensor is wired, or when running on the Mac, the "Pretend someone's here" switch stands in for it. The sensor is an LD2410C: VCC to 5V (pin 2), GND to ground (pin 6), OUT to GPIO17 (pin 11). It is read using gpiozero, which comes with Raspberry Pi OS, so on the Pi create the virtual environment with `python3 -m venv --system-site-packages .venv` to keep access to it.

## Setting up the Pi

1. Flash the microSD from the Mac using Raspberry Pi Imager. Choose Raspberry Pi 4 and Raspberry Pi OS (64-bit), the version with desktop, because the kiosk needs it. In the customisation step:
   - hostname `mirror`
   - your username and password
   - Wi-Fi name and password, and your time zone
   - turn on SSH with public-key authentication, using the Mac's key (`~/.ssh/id_rsa.pub`)
2. Boot the Pi on any TV first, to check the Pi and the micro HDMI cable before they go into the Mirror. Use HDMI0, the port next to USB-C power.
3. Once `ssh <user>@mirror.local` works from the Mac, copy the portal over: `portal/deploy.sh <user>@mirror.local`. It copies `config.json` too, and `spotify_token.json` the first time only.
4. On the Pi (`ssh <user>@mirror.local`), run `cd ~/mirror/portal && bash setup-pi.sh`, then `sudo reboot`. The script:
   - installs Chromium and the Python packages
   - starts the server on boot as the `mirror-portal` service, so the remote works at `mirror.local:8080/remote`
   - boots to the desktop with screen blanking off
   - opens the mirror page full screen, turned for the portrait panel (`kiosk.sh`)
   - installs raspotify as a Spotify speaker named after `spotify.device` ("Mirror"). Use `--no-spotify` to skip it.
5. If the picture comes out upside down, run `bash setup-pi.sh --rotate 270` and reboot.
6. For the speakers, set `LIBRESPOT_DEVICE` in `/etc/raspotify/conf` once you know the audio path (list the choices with `librespot --device ?`), then run `sudo systemctl restart raspotify`.

After a code or config change on the Mac, run `portal/deploy.sh <user>@mirror.local` again. It restarts the server, and the mirror page reloads itself. Server logs are in `journalctl -u mirror-portal`.
