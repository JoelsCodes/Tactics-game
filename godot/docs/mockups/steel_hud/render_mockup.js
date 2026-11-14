// Saves frame_1.png .. frame_3.png from index.html (Playwright, headless Chromium): node render_mockup.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'index.html'));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(500);
  const frames = await page.$$('.frame');
  for (let i = 0; i < frames.length; i++) await frames[i].screenshot({ path: path.join(__dirname, `frame_${i + 1}.png`) });
  await browser.close();
  console.log('saved', frames.length, 'frames');
})();
