const { chromium } = require('/home/pi/.local/share/mise/installs/npm-playwright/latest/node_modules/playwright');
const assert = require('node:assert/strict');
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true });
  try {
    const page = await browser.newPage();
    await page.goto('file:///home/pi/Projects/omarchy.doctor.plugin/design/doctor-concept.html');
    const result = await page.evaluate(() => {
      function visibility(hidden) {
        Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden });
        document.dispatchEvent(new Event('visibilitychange'));
      }
      visibility(true);
      const hiddenPaused = document.documentElement.classList.contains('paused');
      visibility(false);
      const shownPaused = document.documentElement.classList.contains('paused');
      document.querySelector('#motion').click();
      visibility(true);
      visibility(false);
      const manualPausePreserved = document.body.classList.contains('paused');
      document.querySelector('#motion').click();
      return { hiddenPaused, shownPaused, manualPausePreserved,
        animation: getComputedStyle(document.querySelector('.orbit')).animationPlayState,
        pressed: document.querySelector('#motion').getAttribute('aria-pressed') };
    });
    assert.deepEqual(result, { hiddenPaused: true, shownPaused: false,
      manualPausePreserved: true, animation: 'running', pressed: 'false' });
    console.log(JSON.stringify({ verdict: 'Kimi finding 6 rejected: the hidden-tab class is cleared on visibility restoration; manual pause remains independent.', ...result }, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
