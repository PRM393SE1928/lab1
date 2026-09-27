// Serve an already-built Flutter web app on a stable local origin.
// Run from any directory: node tool/serve_web.cjs
const http = require('http');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../build/web');
const mime = {
  '.html': 'text/html; charset=utf-8', '.js': 'application/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm',
  '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
};
if (!fs.existsSync(path.join(root, 'index.html'))) {
  throw Error('Build the app first with flutter build web.');
}
http.createServer((req, res) => {
  if (!['GET', 'HEAD'].includes(req.method)) {
    res.writeHead(405); res.end(); return;
  }
  try {
    const url = new URL(req.url, 'http://127.0.0.1:8081');
    const pathname = decodeURIComponent(url.pathname);
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep) || !fs.statSync(file).isFile()) {
      res.writeHead(404); res.end(); return;
    }
    res.writeHead(200, {
      'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
      'Content-Length': fs.statSync(file).size,
    });
    if (req.method === 'HEAD') res.end();
    else fs.createReadStream(file).pipe(res);
  } catch {
    res.writeHead(404); res.end();
  }
}).listen(8081, '127.0.0.1', () => console.log('Test Case Review: http://127.0.0.1:8081'));
