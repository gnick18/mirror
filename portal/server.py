#!/usr/bin/env python3
"""Mirror portal server.

Serves the web UI in web/ (the mirror at /, the phone remote at /remote) and a small JSON API:
  /api/config    display settings from config.json (calendar URLs left out)
  /api/calendar  upcoming events from the ICS feeds listed in config.json
  /api/state     GET: what the mirror should show (presence, remote settings, file version)
                 POST: change remote settings, e.g. {"mode": "off"} or {"hidden": ["weather"]}

Run: python3 server.py [--host 127.0.0.1] [--port 8080]
"""

import argparse
import json
import sys
import threading
import time
import urllib.request
from datetime import date, datetime, timedelta
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WEB = ROOT / "web"
CONFIG = ROOT / "config.json"
EXAMPLE_CONFIG = ROOT / "config.example.json"
STATE_FILE = ROOT / "state.json"
ICS_CACHE_SECONDS = 15 * 60
WIDGETS = ("clock", "weather", "agenda")
MODES = ("auto", "on", "off")  # auto = follow the presence sensor, off = plain mirror

_ics_cache = {}  # url -> (fetched_at, bytes)
_ics_lock = threading.Lock()

# Remote settings. mode and hidden survive restarts (state.json). simulate is the
# remote's "pretend someone's here" switch, used while no sensor is connected.
_state = {"mode": "auto", "hidden": [], "simulate": True, "reload": 0}
_state_lock = threading.Lock()
SAVED_KEYS = ("mode", "hidden")


class Presence:
    """Someone in front of the mirror, read from the LD2410C's OUT pin (high = person)."""

    def __init__(self, gpio=None, hold_seconds=30):
        self.hold = hold_seconds
        self.last_seen = 0.0
        self.device = None
        self.detail = "not configured"
        if gpio is None:
            return
        try:
            from gpiozero import DigitalInputDevice

            self.device = DigitalInputDevice(gpio, pull_up=False)
            self.detail = f"GPIO{gpio}"
        except Exception as e:  # not on a Pi, or gpiozero missing
            self.detail = f"unavailable ({e})"
            print(f"presence sensor {self.detail}, using the remote's test switch", file=sys.stderr)

    @property
    def connected(self):
        return self.device is not None

    def detected(self, simulate):
        if not self.connected:
            return simulate
        # Sampled on each request. The mirror polls every second and the sensor holds
        # OUT high for a few seconds itself, so nothing is missed.
        if self.device.value:
            self.last_seen = time.time()
        return time.time() - self.last_seen < self.hold


presence = Presence()


def load_state():
    try:
        saved = json.loads(STATE_FILE.read_text())
        _state.update({k: saved[k] for k in SAVED_KEYS if k in saved})
    except (FileNotFoundError, ValueError):
        pass


def update_state(patch):
    with _state_lock:
        if patch.get("mode") in MODES:
            _state["mode"] = patch["mode"]
        if isinstance(patch.get("hidden"), list):
            _state["hidden"] = [w for w in WIDGETS if w in patch["hidden"]]
        if isinstance(patch.get("simulate"), bool):
            _state["simulate"] = patch["simulate"]
        if patch.get("reload"):
            _state["reload"] += 1
        STATE_FILE.write_text(json.dumps({k: _state[k] for k in SAVED_KEYS}))
    return current_state()


def current_state():
    with _state_lock:
        s = dict(_state)
    someone = presence.detected(s["simulate"])
    show = {"on": True, "off": False}.get(s["mode"], someone)
    return {
        **s,
        "someone": someone,
        "show": show,
        "sensor": {"connected": presence.connected, "detail": presence.detail},
        "version": version(),  # the mirror reloads itself when this changes
    }


def config_path():
    return CONFIG if CONFIG.exists() else EXAMPLE_CONFIG


def read_config():
    with open(config_path()) as f:
        return json.load(f)


def public_config(cfg):
    # Calendar URLs are secret links, so they never leave the server.
    return {k: v for k, v in cfg.items() if k != "calendars"}


def version():
    files = [p for p in WEB.rglob("*") if p.is_file()] + [config_path()]
    return str(max(p.stat().st_mtime_ns for p in files))


def fetch_ics(url):
    url = url.replace("webcal://", "https://", 1)
    with _ics_lock:
        hit = _ics_cache.get(url)
    if hit and time.time() - hit[0] < ICS_CACHE_SECONDS:
        return hit[1]
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "mirror-portal"})
        with urllib.request.urlopen(req, timeout=20) as r:
            data = r.read()
    except Exception as e:
        if hit:  # keep showing the last good copy while offline
            print(f"calendar fetch failed, using cached copy: {e}", file=sys.stderr)
            return hit[1]
        raise
    with _ics_lock:
        _ics_cache[url] = (time.time(), data)
    return data


def event_json(ev, cal, tz):
    start = ev["DTSTART"].dt
    if "DTEND" in ev:
        end = ev["DTEND"].dt
    elif "DURATION" in ev:
        end = start + ev["DURATION"].dt
    else:
        end = start + (timedelta(days=1) if not isinstance(start, datetime) else timedelta(0))

    def iso(d):
        if not isinstance(d, datetime):
            return d.isoformat()  # all-day events stay plain dates
        return (d if d.tzinfo else d.replace(tzinfo=tz)).astimezone(tz).isoformat()

    return {
        "title": str(ev.get("SUMMARY", "(no title)")),
        "start": iso(start),
        "end": iso(end),
        "allDay": not isinstance(start, datetime),
        "calendar": cal.get("name", ""),
        "color": cal.get("color", ""),
    }


def upcoming_events(cfg):
    calendars = cfg.get("calendars", [])
    if not calendars:
        return {"demo": True, "events": demo_events(), "errors": []}

    # Imported here so the UI can run in demo mode without the packages installed.
    import icalendar
    import recurring_ical_events

    tz = datetime.now().astimezone().tzinfo
    start = datetime.now(tz).replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=cfg.get("calendarDays", 7))
    events, errors = [], []
    for cal in calendars:
        try:
            ics = icalendar.Calendar.from_ical(fetch_ics(cal["url"]))
            for ev in recurring_ical_events.of(ics).between(start, end):
                events.append(event_json(ev, cal, tz))
        except Exception as e:
            errors.append(f"{cal.get('name', 'calendar')}: {e}")
            print(f"calendar error: {errors[-1]}", file=sys.stderr)
    events.sort(key=lambda e: e["start"])
    return {"demo": False, "events": events, "errors": errors}


def demo_events():
    tz = datetime.now().astimezone().tzinfo
    today = date.today()

    def at(days, hour, minute, hours=1.0):
        s = datetime(today.year, today.month, today.day, hour, minute, tzinfo=tz) + timedelta(days=days)
        return s.isoformat(), (s + timedelta(hours=hours)).isoformat()

    def all_day(days):
        d = today + timedelta(days=days)
        return d.isoformat(), (d + timedelta(days=1)).isoformat()

    rows = [
        ("Coffee with a friend", *at(0, 9, 30), False),
        ("Lab meeting", *at(0, 13, 0), False),
        ("Climbing gym", *at(0, 18, 30, 2), False),
        ("Recycling pickup", *all_day(1), True),
        ("Dentist", *at(1, 10, 0), False),
        ("Seminar", *at(2, 16, 0), False),
        ("Dinner reservation", *at(3, 19, 30, 2), False),
        ("Farmers market", *at(5, 9, 0, 3), False),
    ]
    return [
        {"title": t, "start": s, "end": e, "allDay": a, "calendar": "Sample", "color": ""}
        for t, s, e, a in rows
    ]


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        try:
            if path == "/api/config":
                return self.send_json(public_config(read_config()))
            if path == "/api/calendar":
                return self.send_json(upcoming_events(read_config()))
            if path == "/api/state":
                return self.send_json(current_state())
        except ModuleNotFoundError as e:
            return self.send_json({"error": f"{e}. Run: pip install -r requirements.txt"}, 500)
        except Exception as e:
            return self.send_json({"error": str(e)}, 500)
        if path == "/remote":
            self.path = "/remote.html"
        return super().do_GET()

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/state":
            return self.send_error(404)
        try:
            length = int(self.headers.get("Content-Length", 0))
            patch = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            return self.send_json({"error": "body must be JSON"}, 400)
        if not isinstance(patch, dict):
            return self.send_json({"error": "body must be a JSON object"}, 400)
        return self.send_json(update_state(patch))

    def send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # No browser caching, so edits show up on the next reload.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_request(self, code="-", size="-"):
        # The page polls the API, so only log problems.
        if str(code) not in ("200", "304"):
            super().log_request(code, size)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1", help="use 0.0.0.0 to view from another computer")
    ap.add_argument("--port", type=int, default=8080)
    args = ap.parse_args()
    global presence
    p = read_config().get("presence", {})
    presence = Presence(p.get("gpio"), p.get("holdSeconds", 30))
    load_state()
    print(f"Mirror portal on http://{args.host}:{args.port} using {config_path().name}")
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
