"""Bus times for the mirror: the next buses from your stops that reach your destination.

Uses Metro Transit's GTFS timetable (downloaded once a day) and its GTFS-Realtime trip
updates for live predictions. Data provided under license granted by City of Madison,
WI, Metro Transit.
"""

import csv
import io
import json
import sys
import threading
import time
import urllib.error
import urllib.request
import zipfile
from datetime import date, datetime, timedelta
from email.utils import formatdate
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent
SCHEDULE_ZIP = ROOT / "gtfs" / "schedule.zip"
SCHEDULE_URL = "https://transitdata.cityofmadison.com/GTFS/mmt_gtfs.zip"
LIVE_URL = "https://metromap.cityofmadison.com/gtfsrt/trips"
SCHEDULE_CHECK_SECONDS = 24 * 3600
LIVE_CACHE_SECONDS = 30
WINDOW_SECONDS = 90 * 60  # how far ahead to look


def fetch(url, since=None, timeout=30):
    """GET a URL. Returns None if the server says it hasn't changed since `since`."""
    headers = {"User-Agent": "mirror-portal"}
    if since:
        headers["If-Modified-Since"] = formatdate(since, usegmt=True)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=timeout) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        if e.code == 304:
            return None
        raise


def seconds(hms):
    # GTFS times can pass 24:00:00 for trips that run after midnight.
    h, m, s = hms.split(":")
    return int(h) * 3600 + int(m) * 60 + int(s)


def table(z, name):
    with z.open(name) as f:
        yield from csv.DictReader(io.TextIOWrapper(f, "utf-8-sig"))


class Timetable:
    """The trips that serve one of the 'from' stops and then one of the 'to' stops."""

    def __init__(self, bus):
        with zipfile.ZipFile(SCHEDULE_ZIP) as z:
            agency = next(table(z, "agency.txt"))
            try:
                self.tz = ZoneInfo(agency["agency_timezone"])
            except Exception:
                self.tz = datetime.now().astimezone().tzinfo

            by_code = {s["stop_code"]: s for s in table(z, "stops.txt")}

            def stops(items):
                found = {}
                for item in items:
                    s = by_code.get(str(item["stop"]))
                    if not s:
                        raise ValueError(f"stop #{item['stop']} isn't in the Metro timetable")
                    found[s["stop_id"]] = (item.get("walk", 0) * 60, item.get("name") or s["stop_name"])
                return found

            self.origins = stops(bus.get("from", []))
            self.targets = stops(bus.get("to", []))

            # stop_times.txt is the big file (tens of MB), so read it with a plain reader
            # and keep only the rows for our stops.
            visits = {}
            with z.open("stop_times.txt") as f:
                rows = csv.reader(io.TextIOWrapper(f, "utf-8-sig"))
                head = next(rows)
                T, S, Q, A, D = (head.index(k) for k in
                                 ("trip_id", "stop_id", "stop_sequence", "arrival_time", "departure_time"))
                for row in rows:
                    if row[S] in self.origins or row[S] in self.targets:
                        visits.setdefault(row[T], []).append((int(row[Q]), row[S], seconds(row[A]), seconds(row[D])))

            routes = {r["route_id"]: r for r in table(z, "routes.txt")}
            only = {str(r) for r in bus.get("routes", [])}
            self.trips = []
            for t in table(z, "trips.txt"):
                v = visits.get(t["trip_id"])
                pick = v and self.best_pair(v)
                if not pick:
                    continue
                route = routes.get(t["route_id"], {})
                name = route.get("route_short_name") or t["route_id"]
                if only and name not in only:
                    continue
                self.trips.append({
                    "trip": t["trip_id"], "service": t["service_id"], "route": name,
                    "headsign": t["trip_headsign"].title(),
                    "color": hex_color(route.get("route_color"), "#ffffff"),
                    "textColor": hex_color(route.get("route_text_color"), "#000000"),
                    **pick,
                })

            self.calendar = {}
            for c in table(z, "calendar.txt"):
                days = [c[d] == "1" for d in ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")]
                self.calendar[c["service_id"]] = (parse_date(c["start_date"]), parse_date(c["end_date"]), days)
            self.exceptions = {}
            if "calendar_dates.txt" in z.namelist():
                for c in table(z, "calendar_dates.txt"):
                    self.exceptions[(c["service_id"], parse_date(c["date"]))] = c["exception_type"] == "1"

    def best_pair(self, visits):
        # A trip can pass several of your stops. Take the one that lets you leave home
        # latest and the one that gets you to work soonest (in that order along the trip).
        best = None
        for seq_a, a, _, dep in visits:
            if a not in self.origins:
                continue
            for seq_b, b, arr, _ in visits:
                if b in self.targets and seq_b > seq_a:
                    key = (self.origins[a][0] - dep, arr + self.targets[b][0])
                    if best is None or key < best[0]:
                        best = (key, {"from": a, "fromSeq": seq_a, "dep": dep, "to": b, "arr": arr})
        return best and best[1]

    def runs(self, service, day):
        if (service, day) in self.exceptions:
            return self.exceptions[(service, day)]
        c = self.calendar.get(service)
        return bool(c) and c[0] <= day <= c[1] and c[2][day.weekday()]


def parse_date(s):
    return date(int(s[:4]), int(s[4:6]), int(s[6:]))


def hex_color(value, default):
    v = (value or "").strip().lstrip("#")
    return f"#{v}" if len(v) == 6 and all(c in "0123456789abcdefABCDEF" for c in v) else default


class Commute:
    """Keeps the timetable loaded (in the background) and answers /api/bus."""

    def __init__(self):
        self.lock = threading.Lock()
        self.key = None  # the bus settings the current timetable was built for
        self.timetable = None
        self.error = None
        self.loading = False
        self.checked = 0.0
        self.live = (0.0, {}, None)  # fetched_at, trip_id -> update, error

    def ensure(self, bus):
        key = json.dumps(bus, sort_keys=True)
        with self.lock:
            if self.loading:
                return
            if key == self.key and time.time() - self.checked < SCHEDULE_CHECK_SECONDS:
                return
            if key != self.key:
                self.timetable, self.error = None, None
            self.key, self.loading = key, True
        threading.Thread(target=self.load, args=(bus, key), daemon=True).start()

    def load(self, bus, key):
        retry_soon = False
        try:
            changed = self.download()
            with self.lock:
                stale = self.timetable is None
            if changed or stale:
                started = time.time()
                built = Timetable(bus)
                print(f"bus timetable: {len(built.trips)} trips for your stops ({time.time() - started:.0f}s)", file=sys.stderr)
                with self.lock:
                    if self.key == key:
                        self.timetable, self.error = built, None
        except Exception as e:
            retry_soon = True
            print(f"bus timetable error: {e}", file=sys.stderr)
            with self.lock:
                self.error = str(e)
        finally:
            with self.lock:
                self.loading = False
                # After a failure, try again in 5 minutes instead of tomorrow.
                self.checked = time.time() - (SCHEDULE_CHECK_SECONDS - 300 if retry_soon else 0)

    def download(self):
        """Fetch the timetable zip if Metro has published a newer one. True if it changed."""
        SCHEDULE_ZIP.parent.mkdir(exist_ok=True)
        since = SCHEDULE_ZIP.stat().st_mtime if SCHEDULE_ZIP.exists() else None
        try:
            data = fetch(SCHEDULE_URL, since, timeout=120)
        except Exception as e:
            if since is None:
                raise
            print(f"timetable download failed, using the saved copy: {e}", file=sys.stderr)
            return False
        if data is None:
            return False
        tmp = SCHEDULE_ZIP.with_suffix(".tmp")
        tmp.write_bytes(data)
        tmp.replace(SCHEDULE_ZIP)
        return True

    def live_updates(self):
        """trip_id -> live prediction, from the GTFS-Realtime feed (cached briefly)."""
        with self.lock:
            fetched_at, updates, error = self.live
        if time.time() - fetched_at < LIVE_CACHE_SECONDS:
            return updates, error
        try:
            from google.transit import gtfs_realtime_pb2 as rt
        except ModuleNotFoundError:
            updates, error = {}, "Live times need gtfs-realtime-bindings (pip install -r requirements.txt)"
        else:
            try:
                feed = rt.FeedMessage()
                feed.ParseFromString(fetch(LIVE_URL, timeout=15))
                updates, error = parse_live(feed, rt), None
            except Exception as e:
                print(f"live bus times unavailable: {e}", file=sys.stderr)
                error = "Live times unavailable, showing the timetable"
                if time.time() - fetched_at > 10 * 60:
                    updates = {}  # too old to trust
        with self.lock:
            self.live = (time.time(), updates, error)
        return updates, error

    def upcoming(self, bus):
        if not bus or not bus.get("from") or not bus.get("to"):
            return {"configured": False, "buses": []}
        out = {"configured": True, "title": bus.get("title", "Next buses"), "buses": []}
        hours = bus.get("hours")
        if hours and not within(hours, datetime.now()):
            return {**out, "offHours": True}
        self.ensure(bus)
        with self.lock:
            tt, error, loading = self.timetable, self.error, self.loading
        if tt is None:
            return {**out, "loading": loading and not error, "error": error}

        live, out["note"] = self.live_updates()
        now = time.time()
        today = datetime.now(tt.tz).date()
        found = []
        for day in (today - timedelta(days=1), today, today + timedelta(days=1)):
            # GTFS times count from noon minus 12 hours, which handles daylight saving days.
            base = datetime(day.year, day.month, day.day, 12, tzinfo=tt.tz).timestamp() - 12 * 3600
            for t in tt.trips:
                walk_from, stop_name = tt.origins[t["from"]]
                dep, arr = base + t["dep"], base + t["arr"]
                if not (now - 3600 < dep - walk_from < now + WINDOW_SECONDS + 3600) or not tt.runs(t["service"], day):
                    continue
                is_live = False
                u = live.get(t["trip"])
                if u and abs(u["first"] - dep) < 3 * 3600:  # the same day's run of this trip
                    if u["canceled"] or t["from"] in u["skipped"]:
                        continue
                    if t["from"] in u["times"]:
                        new_dep = u["times"][t["from"]][1]
                        arr = u["times"][t["to"]][0] if t["to"] in u["times"] else arr + (new_dep - dep)
                        dep = new_dep
                        is_live = u["vehicle"]
                    elif u["lastSeq"] < t["fromSeq"] or t["from"] in u["nodata"]:
                        pass  # no prediction that far along the trip yet, so use the timetable
                    else:
                        continue  # already passed this stop, or detoured away from it
                leave, arrive = dep - walk_from, arr + tt.targets[t["to"]][0]
                if now - 30 <= leave <= now + WINDOW_SECONDS:
                    found.append((leave, arrive, dep, is_live, stop_name, t))

        # One row per route, soonest first, with that route's next two buses after it.
        found.sort(key=lambda f: f[0])
        by_route = {}
        for f in found:
            by_route.setdefault(f[5]["route"], []).append(f)

        iso = lambda ts: datetime.fromtimestamp(ts, tt.tz).isoformat(timespec="seconds")
        out["buses"] = [
            {
                "route": t["route"], "headsign": t["headsign"], "color": t["color"], "textColor": t["textColor"],
                "stop": stop_name, "leave": iso(leave), "depart": iso(dep), "arrive": iso(arrive), "live": is_live,
                "then": [iso(f[0]) for f in later[:2]],
            }
            for (leave, arrive, dep, is_live, stop_name, t), *later in list(by_route.values())[: bus.get("count", 4)]
        ]

        # Routes from the config with no bus soon (finished for the day, or a gap in the
        # timetable) get a dim line saying when the next one leaves, so they don't just vanish.
        shown = {b["route"] for b in out["buses"]}
        waiting = [str(r) for r in bus.get("routes", []) if str(r) not in shown]
        out["later"] = []
        for name in waiting[: max(0, bus.get("count", 4) - len(out["buses"]))]:
            nxt = None
            for day in (today, today + timedelta(days=1), today + timedelta(days=2), today + timedelta(days=3)):
                base = datetime(day.year, day.month, day.day, 12, tzinfo=tt.tz).timestamp() - 12 * 3600
                for t in tt.trips:
                    if t["route"] != name or not tt.runs(t["service"], day):
                        continue
                    leave = base + t["dep"] - tt.origins[t["from"]][0]
                    if leave > now and (nxt is None or leave < nxt[0]):
                        nxt = (leave, t)
                if nxt:
                    break
            if nxt:
                leave, t = nxt
                out["later"].append({"route": name, "color": t["color"], "textColor": t["textColor"], "leave": iso(leave),
                                     "today": datetime.fromtimestamp(leave, tt.tz).date() == datetime.now(tt.tz).date()})
        return out


def parse_live(feed, rt):
    """trip_id -> predicted stop times. A trip can be listed twice: once as planned (the
    whole trip) and once from its bus (only the next stops). Merge the two, carrying the
    bus's current delay forward to the stops it has no prediction for yet."""
    canceled = rt.TripDescriptor.CANCELED
    skipped = rt.TripUpdate.StopTimeUpdate.SKIPPED
    no_data = rt.TripUpdate.StopTimeUpdate.NO_DATA
    trips = {}
    for e in feed.entity:
        if not e.HasField("trip_update"):
            continue
        tu = e.trip_update
        # Detoured trips carry their timetable trip_id in modified_trip instead.
        trip_id = tu.trip.trip_id or tu.trip.modified_trip.affected_trip_id
        t = trips.setdefault(trip_id, {"canceled": False, "skipped": set(), "nodata": set(), "planned": [], "bus": None})
        t["canceled"] |= tu.trip.schedule_relationship == canceled
        rows = []
        for s in tu.stop_time_update:
            if s.schedule_relationship == skipped:
                t["skipped"].add(s.stop_id)
            elif s.schedule_relationship == no_data:
                t["nodata"].add(s.stop_id)
            elif s.arrival.time or s.departure.time:
                rows.append((s.stop_sequence, s.stop_id, s.arrival.time or s.departure.time, s.departure.time or s.arrival.time))
        t["bus" if tu.HasField("vehicle") else "planned"] = sorted(rows)

    updates = {}
    for trip_id, t in trips.items():
        times, delay, last_seq = {}, 0, 0
        if t["bus"]:
            planned_at = {sid: arr for _, sid, arr, _ in t["planned"]}
            for seq, sid, arr, dep in t["bus"]:
                times[sid] = (arr, dep)
                delay = arr - planned_at.get(sid, arr)
                last_seq = seq
        # Planned stops beyond the bus's predictions. Stops before them it has already passed.
        for seq, sid, arr, dep in t["planned"]:
            if seq > last_seq or not t["bus"]:
                times[sid] = (arr + delay, dep + delay)
        last_seq = max([last_seq] + [r[0] for r in t["planned"]])
        if not times and not t["canceled"]:
            continue
        updates[trip_id] = {
            "canceled": t["canceled"], "vehicle": bool(t["bus"]), "times": times, "lastSeq": last_seq,
            "skipped": t["skipped"], "nodata": t["nodata"],
            "first": min((v[0] for v in times.values()), default=time.time()),
        }
    return updates


def within(hours, now):
    to_min = lambda s: int(s.split(":")[0]) * 60 + int(s.split(":")[1])
    mins = now.hour * 60 + now.minute
    start, end = to_min(hours["from"]), to_min(hours["to"])
    return mins >= start or mins < end if start > end else start <= mins < end
