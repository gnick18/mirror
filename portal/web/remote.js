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

  const sensor = state.sensor.connected;
  $("simulate").checked = state.simulate;
  $("simulate").disabled = sensor;
  $("sensor-note").textContent = sensor ? "Sensor connected, so this is ignored" : "Stands in for the sensor until it's wired";

  const who = sensor ? (state.someone ? "someone's here" : "nobody's here") : "no sensor";
  $("status-text").textContent = `${state.show ? "Showing widgets" : "Plain mirror"} · ${who}`;
  $("status").classList.toggle("showing", state.show);
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
$("reload").addEventListener("click", () => send({ reload: true }));

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
