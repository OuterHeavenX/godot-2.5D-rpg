// Boot an exported web build in headless Chromium, click PLAY, skip the intro,
// and screenshot the in-game HUD. Fails if the page logs any error.
//   node tools/web_screenshot.js <build dir> [out.png]
// Needs `npm i playwright` and a Chromium (CHROME_PATH overrides Playwright's).
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const dir = process.argv[2]; const out = process.argv[3] || `${dir}/hud.png`; const port = 8766;
(async () => {
  const srv = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: dir, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 1200));
  const launch = {
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
  };
  if (process.env.CHROME_PATH) launch.executablePath = process.env.CHROME_PATH;
  const browser = await chromium.launch(launch);
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('PAGEERROR ' + e.message));
  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'load' });
  await page.waitForTimeout(12000);
  await page.mouse.click(640, 403);           // PLAY
  await page.waitForTimeout(1500);
  await page.mouse.click(1195, 48);           // SKIP intro
  await page.waitForTimeout(2500);
  await page.screenshot({ path: out });
  console.log('errors:', errors.length ? errors.join('\n') : 'none');
  await browser.close(); srv.kill();
  if (errors.length) process.exit(1);
})().catch(e => { console.error('HARNESS', e); process.exit(1); });
