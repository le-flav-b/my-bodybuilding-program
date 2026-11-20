// Screenshots preview pages (uses the preinstalled Playwright).
//   node design/preview/tools/shoot.mjs <page.html> <out.png|out_dir> [selector] [scale]
// No selector: full page to <out.png>.
// With selector: each match is shot; if it has data-shot="name", it goes to <out_dir>/name.png.
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const [, , page, out, sel, scale = '2'] = process.argv;
const browser = await chromium.launch();
const ctx = await browser.newContext({ deviceScaleFactor: Number(scale), viewport: { width: Number(process.env.VW || 1200), height: 900 } });
const p = await ctx.newPage();
await p.goto(pathToFileURL(path.resolve(here, '..', page)).href);
await p.evaluate(() => document.fonts.ready);
await p.waitForTimeout(400);
if (!sel) {
  await p.screenshot({ path: out, fullPage: true });
  console.log(out);
} else {
  const els = await p.$$(sel);
  for (let i = 0; i < els.length; i++) {
    const name = await els[i].getAttribute('data-shot');
    const file = name ? path.join(out, `${name}.png`) : out.replace(/\.png$/, els.length > 1 ? `_${i + 1}.png` : '.png');
    await els[i].screenshot({ path: file });
    console.log(file);
  }
}
await browser.close();
