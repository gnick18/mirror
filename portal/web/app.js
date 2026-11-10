// Mirror portal: clock, weather (Open-Meteo, no API key), bus times, Spotify and calendar agenda.
const STAGE_W = 1080;
const STAGE_H = 1920;
const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const WIDGETS = ["clock", "weather", "bus", "music", "agenda"];

let cfg = {};
let agenda = { events: [] };
let state = { show: true, hidden: [] }; // from /api/state: presence + remote settings
let bus = { buses: [] };
let music = null;

// ---------- layout ----------

function fit() {
  const s = Math.min(innerWidth / STAGE_W, innerHeight / STAGE_H);
  const x = (innerWidth - STAGE_W * s) / 2;
  const y = (innerHeight - STAGE_H * s) / 2;
  $("stage").style.transform = `translate(${x}px, ${y}px) scale(${s})`;
  document.documentElement.style.setProperty("--scale", s); // the ring light is sized in stage pixels
}

// ---------- clock ----------

function formatTime(d, withAmPm = true) {
  let h = d.getHours();
  const m = String(d.getMinutes()).padStart(2, "0");
  if (cfg.clock24) return `${String(h).padStart(2, "0")}:${m}`;
  const ampm = h < 12 ? "AM" : "PM";
  h = h % 12 || 12;
  return withAmPm ? `${h}:${m} ${ampm}` : `${h}:${m}`;
}

function tickClock() {
  const now = new Date();
  $("hm").textContent = formatTime(now, false);
  $("ampm").textContent = cfg.clock24 ? "" : now.getHours() < 12 ? "AM" : "PM";
  $("sec").textContent = cfg.showSeconds ? String(now.getSeconds()).padStart(2, "0") : "";
  $("date").textContent = now.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
  updateOpacity(now);
  setTimeout(tickClock, 1000 - now.getMilliseconds());
}

// Night mode: between dim.from and dim.to everything is shown dimmer.
function isNight(now) {
  const d = cfg.dim;
  if (!d) return false;
  const toMin = (s) => s.split(":").reduce((h, m) => Number(h) * 60 + Number(m));
  const mins = now.getHours() * 60 + now.getMinutes();
  const from = toMin(d.from);
  const to = toMin(d.to);
  return from > to ? mins >= from || mins < to : mins >= from && mins < to;
}

// Black is plain mirror, so "hidden" just means fading the whole stage to 0.
function updateOpacity(now = new Date()) {
  const stage = $("stage");
  const target = !state.show ? 0 : isNight(now) ? cfg.dim.brightness : 1;
  const current = stage.style.opacity === "" ? 1 : Number(stage.style.opacity);
  if (current === target) return;
  // Quick fade in when someone walks up, slow fade out when they leave.
  stage.style.transitionDuration = target > current ? "0.8s" : "3s";
  stage.style.opacity = target;
}

// ---------- weather ----------

// WMO weather codes used by Open-Meteo: [description, icon]
const WMO = {
  0: ["Clear", "clear"], 1: ["Mostly clear", "clear"], 2: ["Partly cloudy", "partly"], 3: ["Cloudy", "cloud"],
  45: ["Fog", "fog"], 48: ["Freezing fog", "fog"],
  51: ["Light drizzle", "rain"], 53: ["Drizzle", "rain"], 55: ["Heavy drizzle", "rain"],
  56: ["Freezing drizzle", "rain"], 57: ["Freezing drizzle", "rain"],
  61: ["Light rain", "rain"], 63: ["Rain", "rain"], 65: ["Heavy rain", "rain"],
  66: ["Freezing rain", "rain"], 67: ["Freezing rain", "rain"],
  71: ["Light snow", "snow"], 73: ["Snow", "snow"], 75: ["Heavy snow", "snow"], 77: ["Snow grains", "snow"],
  80: ["Showers", "rain"], 81: ["Showers", "rain"], 82: ["Heavy showers", "rain"],
  85: ["Snow showers", "snow"], 86: ["Heavy snow showers", "snow"],
  95: ["Thunderstorms", "storm"], 96: ["Thunderstorms, hail", "storm"], 99: ["Thunderstorms, hail", "storm"],
};

// Line icons on a 48x48 grid. Clouds are filled black so they hide whatever is behind them.
const CLOUD = '<path fill="#000" d="M15 34H34A7 7 0 0 0 35 20.1A10 10 0 0 0 16 18.5A8 8 0 0 0 15 34Z"/>';
const SUN = (cx, cy, r) => {
  const rays = [...Array(8)].map((_, i) => {
    const a = (i * Math.PI) / 4;
    const p = (k) => `${(cx + Math.cos(a) * r * k).toFixed(1)} ${(cy + Math.sin(a) * r * k).toFixed(1)}`;
    return `M${p(1.6)}L${p(2.2)}`;
  });
  return `<g class="sun"><circle cx="${cx}" cy="${cy}" r="${r}"/><path d="${rays.join("")}"/></g>`;
};
const MOON = (s, dx, dy) =>
  `<path class="moon" transform="translate(${dx} ${dy}) scale(${s})" d="M30 9A15 15 0 1 0 39 33A12 12 0 0 1 30 9Z"/>`;

function iconSvg(kind, isDay = true) {
  const up = (svg) => `<g transform="translate(0 -6)">${svg}</g>`;
  const parts = {
    clear: isDay ? SUN(24, 24, 7) : MOON(1, 0, 0),
    partly: (isDay ? SUN(17, 17, 5) : MOON(0.6, 4, 4)) + `<g transform="translate(3 3)">${CLOUD}</g>`,
    cloud: CLOUD,
    fog: '<path d="M9 17H39M6 24H34M12 31H42M9 38H31"/>',
    rain: up(CLOUD) + '<path class="drops" d="M19 33L16 40M26 33L23 40M33 33L30 40"/>',
    snow: up(CLOUD) + [[18, 35], [25, 38], [32, 35], [21, 43], [29, 43]]
      .map(([x, y]) => `<circle class="flake" cx="${x}" cy="${y}" r="1.6"/>`).join(""),
    storm: up(CLOUD) + '<path class="bolt" d="M26 29L21 37H27L23 45"/>',
  };
  return `<svg viewBox="0 0 48 48" aria-hidden="true">${parts[kind] || parts.cloud}</svg>`;
}

async function updateWeather() {
  const { latitude, longitude } = cfg.location;
  const metric = cfg.units === "metric";
  const q = new URLSearchParams({
    latitude, longitude, timezone: "auto", forecast_days: 2,
    current: "temperature_2m,apparent_temperature,weather_code,is_day",
    hourly: "temperature_2m,weather_code,precipitation_probability,is_day",
    daily: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max",
    temperature_unit: metric ? "celsius" : "fahrenheit",
  });
  try {
    const r = await fetch(`https://api.open-meteo.com/v1/forecast?${q}`);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    renderWeather(await r.json());
    setTimeout(updateWeather, 15 * 60e3);
  } catch (e) {
    console.warn("weather", e);
    if (!$("w-temp").textContent) $("w-desc").textContent = "Weather unavailable";
    setTimeout(updateWeather, 60e3); // offline at boot, try again soon
  }
}

function renderWeather(w) {
  const t = (v) => `${Math.round(v)}°`;
  const c = w.current;
  const d = w.daily;
  const [desc, kind] = WMO[c.weather_code] || ["", "cloud"];
  $("w-icon").innerHTML = iconSvg(kind, c.is_day === 1);
  $("w-temp").textContent = t(c.temperature_2m);
  $("w-desc").textContent = desc;
  const meta = [`H ${t(d.temperature_2m_max[0])}`, `L ${t(d.temperature_2m_min[0])}`];
  if (Math.abs(c.apparent_temperature - c.temperature_2m) >= 3) meta.push(`Feels ${t(c.apparent_temperature)}`);
  if (d.precipitation_probability_max[0] >= 20) meta.push(`${d.precipitation_probability_max[0]}% precip`);
  $("w-meta").textContent = meta.join("  ·  ");

  // Today in five timepoints, three hours apart, starting with the current hour.
  // Late in the evening the last points run into the night and early morning.
  const h = w.hourly;
  const start = Math.max(0, h.time.indexOf(c.time.slice(0, 13) + ":00"));
  const pts = [0, 3, 6, 9, 12].map((k) => start + k).filter((i) => i < h.time.length);
  const hourLabel = (iso, k) => {
    if (k === 0) return "Now";
    const hr = Number(iso.slice(11, 13));
    return `${hr % 12 || 12}<small>${hr < 12 ? "AM" : "PM"}</small>`;
  };
  const temps = pts.map((i) => h.temperature_2m[i]);
  const lo = Math.min(...temps), hi = Math.max(...temps), span = Math.max(4, hi - lo);
  // A small temperature curve above the numbers: higher dot = warmer.
  const W = 100 * pts.length, y = (v) => 44 - ((v - lo) / span) * 36;
  const xy = temps.map((v, k) => [50 + k * 100, y(v)]);
  const curve = `<svg class="w-curve" viewBox="0 0 ${W} 52" preserveAspectRatio="none" aria-hidden="true">` +
    `<polyline points="${xy.map((p) => p.join(",")).join(" ")}"/>` +
    xy.map(([x, yy]) => `<circle cx="${x}" cy="${yy}" r="5"/>`).join("") + "</svg>";
  const cols = pts.map((i, k) => {
    const kindI = (WMO[h.weather_code[i]] || [])[1];
    const rain = h.precipitation_probability[i];
    return `<li class="w-hour${k === 0 ? " now" : ""}"><span class="t">${hourLabel(h.time[i], k)}</span>` +
      `<span class="icon">${iconSvg(kindI, h.is_day[i] === 1)}</span>` +
      `<span class="temp">${t(h.temperature_2m[i])}</span>` +
      `<span class="pop">${rain >= 20 ? rain + "%" : ""}</span></li>`;
  });
  $("w-days").innerHTML = `<li class="w-curve-row">${curve}</li>` + cols.join("");
}

// ---------- calendar ----------

function localDate(s) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

async function updateAgenda() {
  try {
    const r = await fetch("/api/calendar");
    const data = await r.json();
    if (!r.ok) throw new Error(data.error || `HTTP ${r.status}`);
    agenda = data;
  } catch (e) {
    console.warn("calendar", e);
    agenda.errors = [String(e.message || e)];
  }
  renderAgenda();
}

// What's left of today, with each person's name. When today is done it shows tomorrow
// instead, and when tomorrow is empty too, each calendar gets a "Nothing left today" line.
function renderAgenda() {
  const now = new Date();
  const today = startOfDay(now);
  const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
  const dayAfter = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 2);
  const all = (agenda.events || []).map((e) => ({
    ...e,
    start: e.allDay ? localDate(e.start) : new Date(e.start),
    end: e.allDay ? localDate(e.end) : new Date(e.end),
  }));
  const max = cfg.maxEvents || 6;
  const left = all.filter((e) => e.end > now && e.start < tomorrow);
  const next = all.filter((e) => e.end > tomorrow && e.start < dayAfter && e.start >= tomorrow);
  const cals = agenda.calendars || [];
  const showTomorrow = !left.length && next.length > 0;
  const events = (showTomorrow ? next : left).slice(0, max);

  const who = (name, color) =>
    name && !agenda.demo ? `<span class="who"${color ? ` style="color:${color}"` : ""}>${escapeHtml(name)}</span>` : "";
  const html = [];
  if (events.length || cals.length) html.push(`<li class="day-label">${showTomorrow ? "Tomorrow" : "Today"}</li>`);
  events.forEach((e, i) => {
    const happening = !showTomorrow && e.start <= now && now < e.end;
    const when = e.allDay ? "All day" : happening ? "Now" : formatTime(e.start);
    const fade = Math.max(0.35, 1 - Math.max(0, i - 3) * 0.12); // later items fade out
    const dot = e.color ? ` style="background:${e.color}"` : "";
    html.push(
      `<li class="event${happening && !e.allDay ? " happening" : ""}" style="opacity:${fade}">` +
      `<span class="dot"${dot}></span><span class="when">${when}</span>` +
      `<span class="title">${escapeHtml(e.title)}</span>${who(e.calendar, e.color)}</li>`
    );
  });
  // Anyone with nothing left today gets a quiet line, so you know the calendar is working.
  if (!showTomorrow) {
    for (const c of cals) {
      if (left.some((e) => e.calendar === c.name)) continue;
      const dot = c.color ? ` style="background:${c.color}"` : "";
      html.push(
        `<li class="event none"><span class="dot"${dot}></span><span class="when">${escapeHtml(c.name)}</span>` +
        `<span class="title">Nothing left today</span></li>`
      );
    }
  }
  $("events").innerHTML = html.join("");

  const notes = [];
  if (agenda.demo && events.length) notes.push("Sample events. Add calendar links to config.json.");
  if (agenda.errors && agenda.errors.length) notes.push(`Calendar problem: ${agenda.errors.join("; ")}`);
  $("agenda-note").textContent = notes.join(" ");
  $("agenda").classList.toggle("empty", !html.length && !notes.length);
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

// ---------- bus ----------

// Bus and Spotify only poll while the widgets are showing, so nothing is fetched
// while nobody is at the mirror.
const visible = (id) => state.show && !state.hidden.includes(id);
let busTimer, musicTimer;
// Shown next to buses that are being tracked. The others are timetable times (and dimmer).
const LIVE_ICON =
  '<svg class="live" viewBox="0 0 24 24" aria-label="live"><path d="M7 17A7 7 0 0 1 7 7M17 7A7 7 0 0 1 17 17' +
  'M10 14A3 3 0 0 1 10 10M14 10A3 3 0 0 1 14 14"/></svg>';

async function updateBus() {
  clearTimeout(busTimer);
  if (visible("bus")) {
    try {
      bus = await (await fetch("/api/bus")).json();
    } catch (e) {
      console.warn("bus", e);
    }
    renderBus();
  }
  busTimer = setTimeout(updateBus, bus.loading ? 3000 : 30e3);
}

function renderBus() {
  const now = Date.now();
  const rows = (bus.buses || []).filter((b) => new Date(b.leave) - now > -60e3);
  const html = rows.map((b) => {
    const mins = Math.round((new Date(b.leave) - now) / 60e3);
    const then = (b.then || []).map((t) => Math.max(0, Math.round((new Date(t) - now) / 60e3)));
    const leave = (mins <= 0 ? "Leave now" : `Leave in ${mins} min`) + (b.live ? LIVE_ICON : "") +
      (then.length ? `<span class="then">then ${then.join(", ")}</span>` : "");
    const info = [b.stop, `arrive ${formatTime(new Date(b.arrive))}`];
    return (
      `<li class="bus${b.live ? "" : " sched"}">` +
      `<span class="route" style="background:${b.color};color:${b.textColor}">${escapeHtml(b.route)}</span>` +
      `<span class="leave">${leave}</span><span class="info">${escapeHtml(info.join("  ·  "))}</span></li>`
    );
  });
  // Configured routes with nothing soon, for example route 28 after its last evening trip.
  for (const b of bus.later || []) {
    const when = formatTime(new Date(b.leave));
    const text = b.today ? `Next at ${when}` : `No more today`;
    const info = b.today ? "No bus in the next 90 min" : `First bus ${when}`;
    html.push(
      `<li class="bus sched later">` +
      `<span class="route" style="background:${b.color};color:${b.textColor}">${escapeHtml(b.route)}</span>` +
      `<span class="leave">${text}</span><span class="info">${escapeHtml(info)}</span></li>`
    );
  }
  $("bus-title").textContent = bus.title || "";
  $("buses").innerHTML = html.join("");
  let note = bus.note || "";
  if (bus.loading) note = "Loading the bus timetable…";
  else if (bus.error) note = `Bus times unavailable: ${bus.error}`;
  else if (!rows.length) note = "";
  $("bus-note").textContent = note;
  // Hidden when not set up, outside the configured hours, or with no buses soon.
  $("bus").classList.toggle("empty", !bus.configured || (!rows.length && !(bus.later || []).length && !bus.loading && !bus.error));
}

// ---------- music ----------

async function updateMusic() {
  clearTimeout(musicTimer);
  if (visible("music")) {
    try {
      music = { ...(await (await fetch("/api/spotify")).json()), at: Date.now() };
    } catch (e) {
      console.warn("spotify", e);
    }
    renderMusic();
  }
  musicTimer = setTimeout(updateMusic, music && music.connected ? 5000 : 60e3);
}

function renderMusic() {
  const p = music && music.playing;
  $("music").classList.toggle("empty", !p || !p.isPlaying);
  if (!p) return;
  if ($("m-art").getAttribute("src") !== p.art) $("m-art").setAttribute("src", p.art || "");
  $("m-title").textContent = p.title;
  $("m-artist").textContent = p.artist;
  // Spotify reports progress when polled. Move the bar along between polls.
  const progress = p.progress + (p.isPlaying ? Date.now() - music.at : 0);
  $("m-progress").style.width = p.duration ? `${Math.min(100, (progress / p.duration) * 100)}%` : "0";
}

// ---------- presence, remote settings, and auto reload ----------

// Polls the server every second. Reloads the page when files change (after a
// git pull on the Pi) or when the remote's "Reload the mirror" button is tapped.
async function watchState() {
  let first = null;
  for (;;) {
    try {
      const was = { bus: visible("bus"), music: visible("music") };
      state = await (await fetch("/api/state")).json();
      const token = `${state.version}:${state.reload}`;
      if (first === null) first = token;
      else if (token !== first) return location.reload();
      for (const id of WIDGETS) $(id).classList.toggle("hidden", state.hidden.includes(id));
      $("ring").classList.toggle("on", Boolean(state.light)); // the server hides the widgets while it's on
      updateOpacity();
      // Someone just walked up: get fresh bus times and music right away.
      if (visible("bus") && !was.bus) updateBus();
      if (visible("music") && !was.music) updateMusic();
    } catch {
      // server restarting, keep polling
    }
    await sleep(1000);
  }
}

// ---------- start ----------

async function start() {
  fit();
  addEventListener("resize", fit);
  // On boot Chromium can start before the server, so wait for it.
  for (;;) {
    try {
      cfg = await (await fetch("/api/config")).json();
      if (cfg.ringLight && cfg.ringLight.width) document.documentElement.style.setProperty("--ring-width", cfg.ringLight.width);
      break;
    } catch {
      await sleep(3000);
    }
  }
  tickClock();
  updateWeather();
  updateAgenda();
  updateBus();
  updateMusic();
  setInterval(updateAgenda, 5 * 60e3);
  setInterval(renderAgenda, 60e3);
  setInterval(renderBus, 15e3);
  setInterval(renderMusic, 1000);
  watchState();
}

start();
