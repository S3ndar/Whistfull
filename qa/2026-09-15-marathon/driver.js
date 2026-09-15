// Minimal Playwright REPL-ish driver for a Flutter web app.
// Usage: node driver.js <script.txt>
// Script commands, one per line:
//   nav <url>
//   wait <ms>
//   screenshot <name>
//   click-semantics-toggle       (clicks Flutter's a11y-enable placeholder)
//   click-text <substring>       (click first semantics node containing text)
//   click-xy <x> <y>
//   fill-text <substring-of-nearby-label> <value>   (best-effort, rarely needed)
//   type <text>
//   key <key>
//   log-tree                     (dump the semantics accessibility tree text)
//   console-errors

const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const path = require('path');

const scriptPath = process.argv[2];
const outDir = process.argv[3] || './screenshots';
fs.mkdirSync(outDir, { recursive: true });

(async () => {
  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=swiftshader', '--ignore-gpu-blocklist'],
  });
  const page = await browser.newPage({ viewport: { width: 420, height: 900 } });
  await page.route('**/*', (route) => {
    const headers = { ...route.request().headers(), 'cache-control': 'no-cache, no-store' };
    route.continue({ headers });
  });
  // Flutter's bootstrap registers a service worker that cache-first-serves
  // main.dart.js etc. — across many rebuild/reload cycles in one sandbox
  // session this can serve a stale bundle even from a fresh browser launch
  // if the disk cache dir is shared. Kill service worker registration
  // entirely so every nav is guaranteed to hit the live server.
  await page.addInitScript(() => {
    if (navigator.serviceWorker) {
      navigator.serviceWorker.register = () => Promise.reject(new Error('disabled for testing'));
      navigator.serviceWorker.getRegistrations?.().then((rs) => rs.forEach((r) => r.unregister()));
    }
  });

  // fonts.gstatic.com is blocked by this sandbox's egress proxy, so the app
  // (which doesn't bundle its own fonts) would render with invisible glyphs.
  // Serve a local TTF for every such request instead — canvaskit's FreeType
  // font loader sniffs the binary format rather than trusting the URL
  // extension, so a .ttf standing in for a requested .woff2 renders fine.
  const localFont = fs.readFileSync('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  await page.route('https://fonts.gstatic.com/**', (route) =>
    route.fulfill({ status: 200, contentType: 'font/ttf', body: localFont })
  );

  const consoleMsgs = [];
  page.on('console', (msg) => consoleMsgs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', (err) => consoleMsgs.push(`[pageerror] ${err.message}`));

  const lines = fs.readFileSync(scriptPath, 'utf8').split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));

  for (const line of lines) {
    const [cmd, ...rest] = line.split(' ');
    const arg = rest.join(' ');
    try {
      if (cmd === 'nav') {
        await page.goto(arg, { waitUntil: 'networkidle', timeout: 30000 });
      } else if (cmd === 'wait') {
        await page.waitForTimeout(parseInt(arg, 10));
      } else if (cmd === 'screenshot') {
        const file = path.join(outDir, `${arg || 'shot'}.png`);
        await page.screenshot({ path: file });
        console.log(`SCREENSHOT ${file}`);
      } else if (cmd === 'click-semantics-toggle') {
        // Flutter renders an invisible (0x0 or offscreen) button that
        // enables the a11y tree. Click it via JS, not Playwright's native
        // click, since native click requires the element in-viewport.
        const clicked = await page.evaluate(() => {
          const el = document.querySelector('flt-semantics-placeholder, flt-glass-pane [role="button"]');
          if (el) { el.click(); return true; }
          return false;
        });
        console.log(clicked ? 'clicked semantics toggle' : 'no semantics toggle found');
      } else if (cmd === 'click-text') {
        const el = page.locator(`text=${arg}`).first();
        await el.click({ timeout: 5000 });
        console.log(`clicked text: ${arg}`);
      } else if (cmd === 'click-xy') {
        const [x, y] = arg.split(' ').map(Number);
        await page.mouse.click(x, y);
        console.log(`clicked xy: ${x},${y}`);
      } else if (cmd === 'type') {
        await page.keyboard.type(arg);
      } else if (cmd === 'key') {
        await page.keyboard.press(arg);
      } else if (cmd === 'log-tree') {
        const snapshot = await page.accessibility.snapshot();
        console.log(JSON.stringify(snapshot, null, 1).slice(0, 8000));
      } else if (cmd === 'dump-tree') {
        // Full, untruncated accessibility snapshot written to a file —
        // log-tree's console output is capped at 8000 chars, far too
        // small once the round history is long (a 100-round marathon).
        const snapshot = await page.accessibility.snapshot();
        const file = path.join(outDir, `${arg || 'tree'}.json`);
        fs.writeFileSync(file, JSON.stringify(snapshot, null, 1));
        console.log(`DUMPED TREE ${file}`);
      } else if (cmd === 'console-errors') {
        console.log('---console---');
        console.log(consoleMsgs.join('\n'));
      } else if (cmd === 'dump-console') {
        const file = path.join(outDir, `${arg || 'console'}.log`);
        fs.writeFileSync(file, consoleMsgs.join('\n'));
        console.log(`DUMPED CONSOLE ${file}`);
      } else {
        console.log(`unknown command: ${line}`);
      }
    } catch (e) {
      console.log(`ERROR on "${line}": ${e.message}`);
    }
  }

  await browser.close();
})();
