#!/usr/bin/env python3
"""Spotify now playing and playback controls for the mirror, using the Spotify Web API.

Log in once (opens the browser, saves spotify_token.json next to this file):
  python3 spotify.py login

Needs a Spotify app of your own (Development Mode, owner on Premium) with the redirect URI
http://127.0.0.1:8888/callback, and its Client ID in config.json under spotify.clientId.
"""

import base64
import hashlib
import json
import os
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TOKEN_FILE = ROOT / "spotify_token.json"
REDIRECT_URI = "http://127.0.0.1:8888/callback"
SCOPES = "user-read-playback-state user-modify-playback-state"
ACCOUNTS = "https://accounts.spotify.com"
API = "https://api.spotify.com/v1"
CACHE_SECONDS = 2  # the mirror and the remote poll, so share one answer between them
ACTIONS = ("play", "pause", "next", "previous", "mirror")


class SpotifyError(Exception):
    pass


def post_form(url, fields):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(fields).encode(),
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise SpotifyError(f"Spotify login failed ({e.code}): {e.read().decode(errors='replace')}") from None


def save_token(client_id, refresh_token):
    TOKEN_FILE.write_text(json.dumps({"client_id": client_id, "refresh_token": refresh_token}))
    os.chmod(TOKEN_FILE, 0o600)


class Spotify:
    def __init__(self):
        self.lock = threading.Lock()
        self.access_token = None
        self.expires = 0.0
        self.cache = (0.0, None)
        self.backoff_until = 0.0

    def status(self, cfg):
        """{"connected": bool, "detail": why not, "playing": track or None}"""
        client_id = (cfg or {}).get("clientId")
        if not client_id:
            return {"connected": False, "detail": "Add your Spotify app's Client ID to config.json", "playing": None}
        if not TOKEN_FILE.exists():
            return {"connected": False, "detail": "Log in once: python3 spotify.py login", "playing": None}
        with self.lock:
            fetched_at, playing = self.cache
        if time.time() - fetched_at < CACHE_SECONDS or time.time() < self.backoff_until:
            return {"connected": True, "detail": "", "playing": playing}
        try:
            data = self.api(client_id, "GET", "/me/player?additional_types=episode")
            playing = track_json(data) if data else None
        except SpotifyError as e:
            print(f"spotify: {e}", file=sys.stderr)
            return {"connected": True, "detail": str(e), "playing": playing}
        with self.lock:
            self.cache = (time.time(), playing)
        return {"connected": True, "detail": "", "playing": playing}

    def control(self, cfg, action):
        client_id = (cfg or {}).get("clientId")
        if action not in ACTIONS:
            raise SpotifyError(f"unknown action {action!r}")
        if not client_id or not TOKEN_FILE.exists():
            raise SpotifyError("Spotify isn't connected yet")
        if action == "mirror":
            # Move playback to the mirror's own Spotify Connect speaker (raspotify on the Pi).
            name = (cfg.get("device") or "Mirror").lower()
            devices = self.api(client_id, "GET", "/me/player/devices").get("devices", [])
            match = next((d for d in devices if d["name"].lower() == name), None)
            if not match:
                raise SpotifyError(f"No Spotify speaker called '{cfg.get('device') or 'Mirror'}' is online")
            self.api(client_id, "PUT", "/me/player", {"device_ids": [match["id"]], "play": True})
        else:
            method = "POST" if action in ("next", "previous") else "PUT"
            self.api(client_id, method, f"/me/player/{action}")
        with self.lock:
            self.cache = (0.0, self.cache[1])  # show the change on the next poll

    def token(self, client_id):
        with self.lock:
            if self.access_token and time.time() < self.expires - 60:
                return self.access_token
            saved = json.loads(TOKEN_FILE.read_text())
            if saved.get("client_id") != client_id:
                raise SpotifyError("spotify_token.json is for a different Client ID. Log in again.")
            t = post_form(f"{ACCOUNTS}/api/token", {
                "grant_type": "refresh_token", "refresh_token": saved["refresh_token"], "client_id": client_id,
            })
            if t.get("refresh_token"):  # Spotify may rotate it, and the old one then stops working
                save_token(client_id, t["refresh_token"])
            self.access_token, self.expires = t["access_token"], time.time() + t.get("expires_in", 3600)
            return self.access_token

    def api(self, client_id, method, path, body=None, retry=True):
        headers = {"Authorization": f"Bearer {self.token(client_id)}"}
        data = None if method == "GET" else b""
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"  # only with a body, or /play rejects it
        req = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                raw = r.read()
                return json.loads(raw) if raw else None  # 204 = nothing playing
        except urllib.error.HTTPError as e:
            if e.code == 401 and retry:
                with self.lock:
                    self.access_token = None
                return self.api(client_id, method, path, body, retry=False)
            if e.code == 429:
                self.backoff_until = time.time() + int(e.headers.get("Retry-After", "30"))
            try:
                msg = json.loads(e.read())["error"]["message"]
            except Exception:
                msg = e.reason
            if e.code == 404 and "device" in str(msg).lower():
                msg = "Nothing is playing. Start Spotify on a speaker first"
            raise SpotifyError(f"{msg} ({e.code})") from None
        except OSError as e:
            raise SpotifyError(f"can't reach Spotify: {e}") from None


def track_json(p):
    item = p.get("item") or {}
    if item.get("type") == "episode":
        artist = (item.get("show") or {}).get("name", "")
        images = item.get("images") or (item.get("show") or {}).get("images") or []
    else:
        artist = ", ".join(a["name"] for a in item.get("artists", []))
        images = (item.get("album") or {}).get("images") or []
    # Images come largest first. Take the smallest one that is still at least 300px.
    art = next((i["url"] for i in reversed(images) if (i.get("width") or 0) >= 300), images[0]["url"] if images else "")
    device = p.get("device") or {}
    return {
        "isPlaying": bool(p.get("is_playing")),
        "title": item.get("name", ""),
        "artist": artist,
        "art": art,
        "progress": p.get("progress_ms") or 0,
        "duration": item.get("duration_ms") or 0,
        "device": device.get("name", ""),
        "volume": device.get("volume_percent"),
    }


# ---------- one-time login (Authorization Code with PKCE, so no client secret) ----------

def login():
    config = ROOT / "config.json"
    client_id = (json.loads(config.read_text()).get("spotify") or {}).get("clientId") if config.exists() else None
    if not client_id:
        sys.exit("Put your Spotify app's Client ID in config.json first, under \"spotify\": {\"clientId\": \"...\"}")

    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    url = f"{ACCOUNTS}/authorize?" + urllib.parse.urlencode({
        "response_type": "code", "client_id": client_id, "scope": SCOPES, "redirect_uri": REDIRECT_URI,
        "code_challenge_method": "S256", "code_challenge": challenge, "state": state,
    })
    result = {}

    class Callback(BaseHTTPRequestHandler):
        def do_GET(self):
            u = urllib.parse.urlparse(self.path)
            if u.path != "/callback":  # e.g. the browser asking for a favicon
                return self.send_error(404)
            q = urllib.parse.parse_qs(u.query)
            if q.get("state", [""])[0] != state:
                result["error"] = "state did not match, try again"
            elif "code" in q:
                result["code"] = q["code"][0]
            else:
                result["error"] = q.get("error", ["no code returned"])[0]
            msg = "Spotify is connected. You can close this tab." if "code" in result else f"Login failed: {result['error']}"
            body = f"<p style='font: 20px system-ui; margin: 40px'>{msg}</p>".encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = HTTPServer(("127.0.0.1", 8888), Callback)
    server.timeout = 30
    print(f"Opening Spotify in your browser. If it doesn't open, go to:\n{url}\n")
    webbrowser.open(url)
    deadline = time.time() + 5 * 60
    while not result and time.time() < deadline:
        server.handle_request()
    server.server_close()
    if not result:
        sys.exit("Timed out waiting for the Spotify login.")
    if "error" in result:
        sys.exit(f"Spotify login failed: {result['error']}")

    t = post_form(f"{ACCOUNTS}/api/token", {
        "grant_type": "authorization_code", "code": result["code"], "redirect_uri": REDIRECT_URI,
        "client_id": client_id, "code_verifier": verifier,
    })
    save_token(client_id, t["refresh_token"])
    print(f"Saved {TOKEN_FILE.name}. The mirror picks it up within a few seconds.")


if __name__ == "__main__":
    if sys.argv[1:] == ["login"]:
        login()
    else:
        print(__doc__)
