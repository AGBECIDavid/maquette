// Headless turntable renderer: serves the GLB to a Chromium WebGL context and
// writes one transparent PNG per requested camera angle.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = __dirname;
const PORT = 8137;

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript',
  '.glb': 'model/gltf-binary', '.json': 'application/json',
};

const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(ROOT, rel === '/' ? 'index.html' : rel);
  if (!file.startsWith(ROOT)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, buf) => {
    if (err) { res.writeHead(404).end('not found'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(buf);
  });
});

// Each shot: [name, width, height, azimuth°, elevation°, distance×, fov]
const shots = JSON.parse(fs.readFileSync(path.join(ROOT, 'shots.json'), 'utf8'));
const outDir = process.argv[2] || path.join(ROOT, 'out');
fs.mkdirSync(outDir, { recursive: true });

(async () => {
  await new Promise(r => server.listen(PORT, r));

  // Use the container's preinstalled Chromium rather than the build this
  // Playwright version would otherwise download, and force software GL so
  // WebGL works without a GPU.
  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => console.log('  [page]', m.text()));

  await page.goto(`http://127.0.0.1:${PORT}/index.html`);

  await page.waitForFunction(
    () => window.__state && (window.__state.ready || window.__state.error),
    null, { timeout: 180000 }
  );

  const st = await page.evaluate(() => window.__state);
  if (st.error) throw new Error('model load failed: ' + st.error);
  console.log('model bbox size:', st.size);

  for (const s of shots) {
    const dataUrl = await page.evaluate(
      ([w, h, az, el, d, fov]) => window.__shoot(w, h, az, el, d, fov),
      [s.w, s.h, s.az, s.el, s.dist, s.fov]
    );
    const b64 = dataUrl.split(',')[1];
    fs.writeFileSync(path.join(outDir, s.name + '.png'), Buffer.from(b64, 'base64'));
    console.log('wrote', s.name, `${s.w}x${s.h}`, `az=${s.az} el=${s.el}`);
  }

  await browser.close();
  server.close();
})().catch(e => { console.error(e); process.exit(1); });
