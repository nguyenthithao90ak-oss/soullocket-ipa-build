// Xuất toàn bộ ảnh Google Play từ index.html.
//   node store_assets/src/render.js            → xuất tất cả
//   node store_assets/src/render.js 01 feature → chỉ xuất slide có tên chứa "01" hoặc "feature"
const path = require('path');
const fs = require('fs');

function loadPlaywright() {
  try {
    return require('playwright');
  } catch (_) {
    const { execSync } = require('child_process');
    const globalRoot = execSync('npm root -g').toString().trim();
    return require(path.join(globalRoot, 'playwright'));
  }
}

(async () => {
  const { chromium } = loadPlaywright();
  const filters = process.argv.slice(2);
  const outRoot = process.env.OUT_DIR || path.resolve(__dirname, '..', 'google_play');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 2000 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'index.html'));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(400);

  const slides = await page.$$('[data-out]');
  for (const slide of slides) {
    const out = await slide.getAttribute('data-out');
    if (filters.length && !filters.some((f) => out.includes(f))) continue;
    const file = path.join(outRoot, out);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await slide.screenshot({ path: file, animations: 'disabled' });
    console.log('✓', path.relative(process.cwd(), file));
  }
  await browser.close();
})();
