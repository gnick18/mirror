// Phone remote for the mirror. Reads and changes the server's /api/state.
const $ = (id) => document.getElementById(id);
let state = null;

const MODE_HINTS = {
  auto: "Widgets show when someone is in front of the mirror.",
  on: "Widgets always show.",
  off: "Plain mirror. Widgets stay hidden.",
};

function render() {
  document.querySelectorAll("[data-mode]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.mode === state.mode)));
  $("mode-hint").textContent = MODE_HINTS[state.mode];
  document.querySelectorAll("[data-widget]").forEach((c) => (c.checked = !state.hidden.includes(c.dataset.widget)));
  $("light").checked = Boolean(state.light);

  const sensor = state.sensor.connected;
  $("simulate").checked = state.simulate;
  $("simulate").disabled = sensor;
  $("sensor-note").textContent = sensor ? "Sensor connected, so this is ignored" : "Stands in for the sensor until it's wired";

  const who = sensor ? (state.someone ? "someone's here" : "nobody's here") : "no sensor";
  const showing = state.light ? "Ring light on" : state.show ? "Showing widgets" : "Plain mirror";
  $("status-text").textContent = `${showing} · ${who}`;
  $("status").classList.toggle("showing", state.show || Boolean(state.light));
}

function offline() {
  $("status-text").textContent = "Can't reach the mirror";
  $("status").classList.remove("showing");
}

async function send(patch) {
  try {
    const r = await fetch("/api/state", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(patch),
    });
    state = await r.json();
    render();
  } catch {
    offline();
  }
}

document.querySelectorAll("[data-mode]").forEach((b) => b.addEventListener("click", () => send({ mode: b.dataset.mode })));
document.querySelectorAll("[data-widget]").forEach((c) =>
  c.addEventListener("change", () => {
    const hidden = [...document.querySelectorAll("[data-widget]")].filter((x) => !x.checked).map((x) => x.dataset.widget);
    send({ hidden });
  })
);
$("simulate").addEventListener("change", (e) => send({ simulate: e.target.checked }));
$("light").addEventListener("change", (e) => send({ light: e.target.checked }));
$("reload").addEventListener("click", () => send({ reload: true }));

// ---------- music ----------

const PLAY = "M7 4v16l13-8z";
const PAUSE = "M6 4h4v16H6zM14 4h4v16h-4z";
let music = null;

function renderMusic() {
  const connected = Boolean(music && music.connected);
  const p = connected ? music.playing : null;
  $("m-controls").hidden = !connected;
  $("m-mirror").hidden = !connected;
  $("m-art").hidden = !(p && p.art);
  if (p && p.art && $("m-art").getAttribute("src") !== p.art) $("m-art").src = p.art;
  if (!connected) {
    $("m-title").textContent = music ? "Spotify isn't connected" : "Can't reach the mirror";
    $("m-sub").textContent = music ? music.detail : "";
    return;
  }
  $("m-title").textContent = p ? p.title : "Nothing playing";
  $("m-sub").textContent = p ? [p.artist, p.device && `on ${p.device}`].filter(Boolean).join(" · ") : music.detail || "Start Spotify on any speaker";
  const playing = Boolean(p && p.isPlaying);
  $("m-toggle").dataset.action = playing ? "pause" : "play";
  $("m-toggle").setAttribute("aria-label", playing ? "Pause" : "Play");
  $("m-toggle-icon").setAttribute("d", playing ? PAUSE : PLAY);
}

async function loadMusic() {
  try {
    music = await (await fetch("/api/spotify")).json();
  } catch {
    music = null;
  }
  renderMusic();
}

document.querySelectorAll("[data-action]").forEach((b) =>
  b.addEventListener("click", async () => {
    try {
      const r = await fetch("/api/spotify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: b.dataset.action }),
      });
      $("m-hint").textContent = (await r.json()).error || "";
    } catch {
      $("m-hint").textContent = "Can't reach the mirror";
    }
    setTimeout(loadMusic, 600); // Spotify takes a moment to report the change
  })
);

// Keep in sync with the sensor and with other phones.
async function poll() {
  try {
    state = await (await fetch("/api/state")).json();
    render();
  } catch {
    offline();
  }
  setTimeout(poll, 2000);
}

poll();
loadMusic();
setInterval(loadMusic, 3000);
