// Exercise Reports > Export Excel in the built app with an isolated Chrome
// profile. Downloads stay under build/export-browser-probe, never user files.
const fs = require('fs');
const path = require('path');
const {spawn} = require('child_process');
const crypto = require('crypto');

(async () => {
  const directory = path.resolve('build/export-browser-probe', crypto.randomUUID());
  const profile = path.join(directory, 'profile');
  const downloads = path.join(directory, 'downloads');
  fs.mkdirSync(downloads, {recursive: true});
  fs.mkdirSync(profile, {recursive: true});
  const chrome = spawn(process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    ['--headless=new', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0',
      `--user-data-dir=${profile}`, 'about:blank'], {windowsHide: true, stdio: 'ignore'});
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  let socket;
  try {
    let port;
    for (let i = 0; i < 100; i++) {
      try { port = fs.readFileSync(path.join(profile, 'DevToolsActivePort'), 'utf8').split('\n')[0]; break; } catch {}
      await delay(100);
    }
    if (!port) throw Error('Chrome debugging port unavailable');
    const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    socket = new WebSocket(pages.find(t => t.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    let id = 0;
    const pending = new Map();
    const errors = [];
    socket.onmessage = event => {
      const value = JSON.parse(event.data);
      if (value.method === 'Runtime.exceptionThrown') errors.push(value.params.exceptionDetails.text);
      if (pending.has(value.id)) { pending.get(value.id)(value); pending.delete(value.id); }
    };
    async function command(method, params = {}) {
      const key = ++id;
      let timer;
      const reply = new Promise((resolve, reject) => {
        pending.set(key, value => { clearTimeout(timer); value.error ? reject(Error(JSON.stringify(value.error))) : resolve(value.result); });
        timer = setTimeout(() => { pending.delete(key); reject(Error(`Timeout: ${method}`)); }, 20000);
      });
      socket.send(JSON.stringify({id: key, method, params}));
      return reply;
    }
    async function evaluate(expression) {
      return (await command('Runtime.evaluate', {expression, returnByValue: true, userGesture: true})).result?.value;
    }
    await command('Runtime.enable');
    await command('Page.enable');
    await command('Emulation.setDeviceMetricsOverride', {width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false});
    await command('Browser.setDownloadBehavior', {behavior: 'allow', downloadPath: downloads});
    await command('Page.navigate', {url: 'http://127.0.0.1:8081/'});
    const findAndClick = label => `(() => {
      function nodes(root) {
        const all = [...root.querySelectorAll('*')];
        return all.concat(all.flatMap(e => e.shadowRoot ? nodes(e.shadowRoot) : []));
      }
      const all = nodes(document);
      const placeholder = all.find(e => e.tagName.toLowerCase() === 'flt-semantics-placeholder');
      if (placeholder) placeholder.click();
      const target = all.find(e => e.getAttribute('role') === 'button' &&
        (e.getAttribute('aria-label') === ${JSON.stringify(label)} || e.textContent.trim() === ${JSON.stringify(label)}));
      if (!target) return false;
      target.click(); return true;
    })()`;
    for (const label of ['Reports', 'Export Excel']) {
      let clicked = false;
      for (let i = 0; i < 120; i++) {
        await delay(500);
        if (await evaluate(findAndClick(label))) { clicked = true; break; }
      }
      if (!clicked) throw Error(`Could not activate ${label}. Browser errors: ${errors.join('; ')}`);
    }
    let file;
    for (let i = 0; i < 120; i++) {
      file = fs.readdirSync(downloads).find(name => name.endsWith('.xlsx'));
      if (file) break;
      await delay(500);
    }
    if (!file) throw Error(`No report downloaded. Browser errors: ${errors.join('; ')}`);
    const bytes = fs.readFileSync(path.join(downloads, file));
    if (bytes[0] !== 0x50 || bytes[1] !== 0x4b || bytes.length < 1000) throw Error('Invalid Excel download');
    console.log(`Chrome export PASS: ${path.join(downloads, file)} (${bytes.length} bytes)`);
  } finally {
    if (socket) socket.close();
    chrome.kill();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
