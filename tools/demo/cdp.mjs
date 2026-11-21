// Tiny headless-Edge driver for testing the HTML demo (docs/demo). No npm packages:
// it speaks the Chrome DevTools Protocol over Node 22's built-in WebSocket.
//
//   import { launch } from "./cdp.mjs";
//   const b = await launch();                 // fresh profile, 390x844 phone viewport
//   await b.open("docs/demo/index.html");      // path relative to the repo, or a full URL
//   await b.click("#new");                     // CSS selector; real mouse press + release at its centre
//   await b.waitFor(() => location.pathname.endsWith("02-character.html"));
//   console.log(await b.eval("document.title"));
//   await b.shot("out.png");
//   console.log(b.errors);                     // console errors + uncaught exceptions so far
//   await b.close();
//
// Run a script with: node tools/demo/<your-test>.mjs
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const EDGE = process.env.EDGE || "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function launch({ width = 390, height = 844, port = 9300 + Math.floor(Math.random() * 600) } = {}) {
  const profile = mkdtempSync(join(process.env.CDP_TMP || tmpdir(), "pumplex-edge-"));
  const proc = spawn(EDGE, [
    "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
    "--allow-file-access-from-files", `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
    `--window-size=${width},${height}`, "about:blank",
  ], { stdio: "ignore" });

  let target;
  for (let i = 0; i < 100 && !target; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      target = list.find((t) => t.type === "page");
    } catch { /* not up yet */ }
    if (!target) await sleep(100);
  }
  if (!target) { proc.kill(); throw new Error("Edge did not start"); }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  let id = 0;
  const pending = new Map();
  const listeners = [];
  const errors = [];
  const logs = [];
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) {
      const { res, rej } = pending.get(msg.id); pending.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
    } else if (msg.method) {
      if (msg.method === "Runtime.exceptionThrown") {
        const d = msg.params.exceptionDetails;
        errors.push(`exception: ${d.exception?.description || d.text} @ ${d.url || ""}:${d.lineNumber}`);
      } else if (msg.method === "Runtime.consoleAPICalled") {
        const text = msg.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
        logs.push(`${msg.params.type}: ${text}`);
        if (msg.params.type === "error") errors.push(`console.error: ${text}`);
      } else if (msg.method === "Log.entryAdded" && msg.params.entry.level === "error") {
        errors.push(`log: ${msg.params.entry.text} ${msg.params.entry.url || ""}`);
      }
      listeners.forEach((fn) => fn(msg));
    }
  };
  const send = (method, params = {}) => new Promise((res, rej) => {
    const n = ++id; pending.set(n, { res, rej }); ws.send(JSON.stringify({ id: n, method, params }));
  });
  const once = (method) => new Promise((r) => { const fn = (m) => { if (m.method === method) { listeners.splice(listeners.indexOf(fn), 1); r(m.params); } }; listeners.push(fn); });

  await send("Page.enable"); await send("Runtime.enable"); await send("Log.enable");
  await send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: true });
  await send("Emulation.setTouchEmulationEnabled", { enabled: true });

  const api = {
    errors, logs, send,
    url(path) {
      if (/^[a-z]+:/i.test(path)) return path;
      const q = path.indexOf("?");
      return q < 0 ? pathToFileURL(join(REPO, path)).href : pathToFileURL(join(REPO, path.slice(0, q))).href + path.slice(q);
    },
    async open(path) {
      const loaded = once("Page.loadEventFired");
      await send("Page.navigate", { url: api.url(path) });
      await loaded; await sleep(150);
    },
    async eval(expr) {
      const src = typeof expr === "function" ? `(${expr})()` : expr;
      const r = await send("Runtime.evaluate", { expression: src, awaitPromise: true, returnByValue: true });
      if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
      return r.result.value;
    },
    async waitFor(fn, { timeout = 5000, every = 100 } = {}) {
      const t0 = Date.now();
      while (Date.now() - t0 < timeout) {
        try { if (await api.eval(fn)) return true; } catch { /* page navigating */ }
        await sleep(every);
      }
      throw new Error("waitFor timed out: " + fn.toString().slice(0, 120));
    },
    async box(selector) {
      return api.eval(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); if (!e) return null;
        e.scrollIntoView({block:"center"}); const r = e.getBoundingClientRect();
        return {x: r.x + r.width/2, y: r.y + r.height/2, w: r.width, h: r.height,
                disabled: !!(e.disabled || e.getAttribute("aria-disabled") === "true")}; })()`);
    },
    // Real mouse press/release (pointer events fire). holdMs > 0 = long press.
    async click(selector, { holdMs = 60 } = {}) {
      const b = await api.box(selector);
      if (!b) throw new Error("click: no element " + selector);
      await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: b.x, y: b.y });
      await send("Input.dispatchMouseEvent", { type: "mousePressed", x: b.x, y: b.y, button: "left", clickCount: 1 });
      await sleep(holdMs);
      await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: b.x, y: b.y, button: "left", clickCount: 1 });
      await sleep(80);
      return b;
    },
    async clickAt(x, y) {
      await send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
      await sleep(60);
      await send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
      await sleep(80);
    },
    async press(key) { // e.g. "Tab", "Enter", " "
      await send("Input.dispatchKeyEvent", { type: "keyDown", key, text: key.length === 1 ? key : undefined });
      await send("Input.dispatchKeyEvent", { type: "keyUp", key });
    },
    async shot(file) {
      const r = await send("Page.captureScreenshot", { format: "png" });
      writeFileSync(file, Buffer.from(r.data, "base64"));
      return file;
    },
    sleep,
    async close() {
      try { ws.close(); } catch {}
      proc.kill();
      await sleep(300);
      try { rmSync(profile, { recursive: true, force: true }); } catch {}
    },
  };
  return api;
}
