// Mirror portal: clock, weather (Open-Meteo, no API key) and calendar agenda.
const STAGE_W = 1080;
const STAGE_H = 1920;
const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let cfg = {};
let agenda = { events: [] };
let state = { show: true, hidden: [] }; // from /api/state: presence + remote settings

// ---------- layout ----------

function fit() {
  const s = Math.min(innerWidth / STAGE_W, innerHeight / STAGE_H);
  const x = (innerWidth - STAGE_W * s) / 2;
  const y = (innerHeight - STAGE_H * s) / 2;
  $("stage").style.transform = `translate(${x}px, ${y}px) scale(${s})`;
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
  return `<circle cx="${cx}" cy="${cy}" r="${r}"/><path d="${rays.join("")}"/>`;
};
const MOON = (s, dx, dy) =>
  `<path transform="translate(${dx} ${dy}) scale(${s})" d="M30 9A15 15 0 1 0 39 33A12 12 0 0 1 30 9Z"/>`;

function iconSvg(kind, isDay = true) {
  const up = (svg) => `<g transform="translate(0 -6)">${svg}</g>`;
  const parts = {
    clear: isDay ? SUN(24, 24, 7) : MOON(1, 0, 0),
    partly: (isDay ? SUN(17, 17, 5) : MOON(0.6, 4, 4)) + `<g transform="translate(3 3)">${CLOUD}</g>`,
    cloud: CLOUD,
    fog: '<path d="M9 17H39M6 24H34M12 31H42M9 38H31"/>',
    rain: up(CLOUD) + '<path d="M19 33L16 40M26 33L23 40M33 33L30 40"/>',
    snow: up(CLOUD) + [[18, 35], [25, 38], [32, 35], [21, 43], [29, 43]]
      .map(([x, y]) => `<circle cx="${x}" cy="${y}" r="1.3" fill="currentColor"/>`).join(""),
    storm: up(CLOUD) + '<path d="M26 29L21 37H27L23 45"/>',
  };
  return `<svg viewBox="0 0 48 48" aria-hidden="true">${parts[kind] || parts.cloud}</svg>`;
}

async function updateWeather() {
  const { latitude, longitude } = cfg.location;
  const metric = cfg.units === "metric";
  const q = new URLSearchParams({
    latitude, longitude, timezone: "auto", forecast_days: 6,
    current: "temperature_2m,apparent_temperature,weather_code,is_day",
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

  const rows = [];
  for (let i = 1; i < d.time.length; i++) {
    const [y, m, day] = d.time[i].split("-").map(Number);
    const name = new Date(y, m - 1, day).toLocaleDateString(undefined, { weekday: "short" });
    const kindI = (WMO[d.weather_code[i]] || [])[1];
    rows.push(
      `<span class="day">${name}</span><span class="icon">${iconSvg(kindI)}</span>` +
      `<span class="hi">${t(d.temperature_2m_max[i])}</span><span class="lo">${t(d.temperature_2m_min[i])}</span>`
    );
  }
  $("w-days").innerHTML = rows.join("");
}

// ---------- calendar ----------

function localDate(s) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function dayLabel(d, today) {
  const diff = Math.round((startOfDay(d) - today) / 864e5);
  if (diff === 0) return "Today";
  if (diff === 1) return "Tomorrow";
  if (diff < 7) return d.toLocaleDateString(undefined, { weekday: "long" });
  return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
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

function renderAgenda() {
  const now = new Date();
  const today = startOfDay(now);
  const events = (agenda.events || [])
    .map((e) => ({
      ...e,
      start: e.allDay ? localDate(e.start) : new Date(e.start),
      end: e.allDay ? localDate(e.end) : new Date(e.end),
    }))
    .filter((e) => e.end > now)
    .slice(0, cfg.maxEvents || 9);

  const html = [];
  let lastLabel = "";
  events.forEach((e, i) => {
    const shown = e.start < today ? today : e.start; // multi-day events that started earlier
    const label = dayLabel(shown, today);
    if (label !== lastLabel) {
      html.push(`<li class="day-label">${label}</li>`);
      lastLabel = label;
    }
    const happening = e.start <= now && now < e.end;
    const when = e.allDay ? "All day" : happening ? "Now" : formatTime(e.start);
    const fade = Math.max(0.35, 1 - Math.max(0, i - 3) * 0.12); // later items fade out
    const dot = e.color ? ` style="background:${e.color}"` : "";
    html.push(
      `<li class="event${happening && !e.allDay ? " happening" : ""}" style="opacity:${fade}">` +
      `<span class="dot"${dot}></span><span class="when">${when}</span>` +
      `<span class="title">${escapeHtml(e.title)}</span></li>`
    );
  });
  if (!events.length) html.push('<li class="day-label">Nothing coming up</li>');
  $("events").innerHTML = html.join("");

  const notes = [];
  if (agenda.demo) notes.push("Sample events. Add calendar links to config.json.");
  if (agenda.errors && agenda.errors.length) notes.push(`Calendar problem: ${agenda.errors.join("; ")}`);
  $("agenda-note").textContent = notes.join(" ");
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

// ---------- presence, remote settings, and auto reload ----------

// Polls the server every second. Reloads the page when files change (after a
// git pull on the Pi) or when the remote's "Reload the mirror" button is tapped.
async function watchState() {
  let first = null;
  for (;;) {
    try {
      state = await (await fetch("/api/state")).json();
      const token = `${state.version}:${state.reload}`;
      if (first === null) first = token;
      else if (token !== first) return location.reload();
      for (const id of ["clock", "weather", "agenda"]) $(id).classList.toggle("hidden", state.hidden.includes(id));
      updateOpacity();
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
      break;
    } catch {
      await sleep(3000);
    }
  }
  tickClock();
  updateWeather();
  updateAgenda();
  setInterval(updateAgenda, 10 * 60e3);
  setInterval(renderAgenda, 60e3);
  watchState();
}

start();
