// Actual Chrome/IndexedDB check without Flutter's CanvasKit test bootstrap.
const fs = require('fs');
const http = require('http');
const path = require('path');
const {spawn} = require('child_process');
const crypto = require('crypto');

(async () => {
  const server = http.createServer((req, res) => {
    if (req.url.startsWith('/probe.js')) {
      res.setHeader('Content-Type', 'application/javascript');
      res.end(fs.readFileSync(path.resolve('build/workspace_web_probe.js')));
    } else {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.end('<!doctype html><meta charset="utf-8"><body>Loading<script src="/probe.js"></script></body>');
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const run = crypto.randomUUID();
  const profile = path.resolve('build', 'browser-storage-probe', run);
  fs.mkdirSync(profile, {recursive: true});
  const chromePath = process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const chrome = spawn(chromePath, ['--headless=new', '--no-first-run', '--no-default-browser-check',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], {windowsHide: true, stdio: 'ignore'});
  let socket;
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  try {
    let port;
    for (let i = 0; i < 100; i++) {
      try { port = fs.readFileSync(path.join(profile, 'DevToolsActivePort'), 'utf8').split('\n')[0]; break; } catch {}
      await delay(100);
    }
    if (!port) throw Error('Chrome debugging port unavailable');
    const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    socket = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    let nextId = 0;
    const waiting = new Map();
    socket.onmessage = event => {
      const response = JSON.parse(event.data);
      if (waiting.has(response.id)) {
        waiting.get(response.id)(response); waiting.delete(response.id);
      }
    };
    async function command(method, params = {}) {
      const id = ++nextId;
      const response = new Promise(resolve => waiting.set(id, resolve));
      socket.send(JSON.stringify({id, method, params}));
      return await Promise.race([response, delay(10000).then(() => { throw Error(`Timeout: ${method}`); })]);
    }
    await command('Page.enable');
    for (const phase of ['write', 'read']) {
      await command('Page.navigate', {url: `http://127.0.0.1:${server.address().port}/?run=${run}&phase=${phase}`});
      let text = '';
      for (let i = 0; i < 150; i++) {
        await delay(100);
        const value = await command('Runtime.evaluate', {expression: 'document.body?.textContent', returnByValue: true});
        text = value.result?.result?.value || '';
        if (text === `PASS ${phase}` || text.startsWith('FAIL')) break;
      }
      if (text !== `PASS ${phase}`) throw Error(`${phase}: ${text}`);
      console.log(`Chrome IndexedDB: ${text}`);
    }
  } finally {
    if (socket) socket.close();
    chrome.kill();
    server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
