// Browser smoke test: drives the real UI through screens and a full story battle (player turns use the AI planner
// but go through the same UI handlers a tap would). Run: NODE_PATH=$(npm root -g) node tests/smoke.js [url]
const { chromium } = require('playwright');
const URL = process.argv[2] || 'http://localhost:8765/';
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 800 } });
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  await p.goto(URL);
  await p.click('[data-a=newgame]');
  await p.click('.panel .btn[data-a=close]');
  await p.evaluate(() => { G.fast = true; });
  // Clan / equipment / job screens
  await p.click('[data-a=tab][data-v=clan]');
  await p.click('[data-a=unit]');
  await p.click('[data-a=pickeq][data-v=w]');
  await p.click('.panel [data-a=equip]'); // remove weapon
  await p.click('[data-a=pickeq][data-v=w]');
  await p.click('.panel [data-a=equip]'); // re-equip
  const w = await p.evaluate(() => G.units[0].eq.w);
  if (w !== 'ironsword') errs.push('re-equip failed: ' + w);
  // Shop
  await p.click('[data-a=tab][data-v=shop]');
  await p.click('[data-a=buy][data-v=dagger]');
  if (!(await p.evaluate(() => G.inv.dagger === 1))) errs.push('buy failed');
  await p.click('[data-a=shoptab][data-v=sell]');
  await p.click('[data-a=shoptab][data-v=bazaar]');
  // Pub -> accept -> travel -> deploy
  await p.click('[data-a=tab][data-v=pub]');
  await p.click('[data-a=accept]');
  await p.click('[data-a=tab][data-v=map]');
  await p.click('g[data-v=briar]');
  await p.click('[data-a=travel]');
  await p.click('[data-a=deploy][data-v=mission]');
  await p.click('[data-a=fight]');
  await p.waitForTimeout(500);
  // One real tap: wait for a player turn, open Move and tap a highlighted tile on the canvas.
  await p.waitForFunction(() => BS.mode === 'menu', null, { timeout: 30000 });
  await p.click('[data-a=bmove]');
  const pt = await p.evaluate(() => {
    const a = BS.actor;
    for (const [k, v] of BS.reach) if (v.d > 0) { const t = tileAt(B, v.x, v.y), [x, y] = iso(v.x, v.y, t.h); if (x > 20 && x < V.w - 20 && y > 20 && y < V.h - 20 && pickTile(x, y) + '' === v.x + ',' + v.y) return { x, y, tx: v.x, ty: v.y }; }
    return null;
  });
  if (pt) {
    const box = await p.locator('#bv').boundingBox();
    await p.mouse.click(box.x + pt.x, box.y + pt.y);
    await p.waitForFunction(() => BS.mode === 'menu' || BS.mode === 'face', null, { timeout: 5000 });
    const pos = await p.evaluate(() => [BS.actor.x, BS.actor.y]);
    if (pos[0] !== pt.tx || pos[1] !== pt.ty) errs.push('tap-move went to ' + pos + ' not ' + [pt.tx, pt.ty]);
  } else errs.push('no tappable move tile found');
  // Let the AI play the rest through the UI handlers.
  const outcome = await p.evaluate(async () => {
    const wait = ms => new Promise(r => setTimeout(r, ms));
    for (let i = 0; i < 4000 && S.scr === 'battle'; i++) {
      if (BS.mode === 'menu') {
        const a = BS.actor, plan = aiPlan(B, a);
        if (!a.moved && (plan.x !== a.x || plan.y !== a.y) && canMove(a)) { BACT.bmove(); await doMove(plan.x, plan.y); continue; }
        if (plan.id && !a.acted) { BACT.bpick(plan.id); BS.center = [plan.cx, plan.cy]; showTargetPanel(); await doAct(); continue; }
        BACT.bwait();
      }
      if (BS.mode === 'face') { BACT.bface(String(BS.actor.f)); }
      await wait(50);
    }
    while (S.scr === 'battle') await wait(100);
    return S.results && S.results.won;
  });
  await p.screenshot({ path: process.env.SHOT || '/dev/null' }).catch(() => {});
  console.log('battle won:', outcome, '| stage', await p.evaluate(() => G.stage), '| gil', await p.evaluate(() => G.gil));
  await p.click('.stick [data-a=tab][data-v=map]');
  // Reload restores the save
  await p.reload();
  await p.click('[data-a=continue]');
  const st = await p.evaluate(() => G && G.battles);
  if (st !== 1) errs.push('save/continue failed: battles=' + st);
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'smoke ok');
  await b.close();
  process.exit(errs.length ? 1 : 0);
})();
