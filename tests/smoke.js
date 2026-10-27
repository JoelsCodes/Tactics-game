// Browser smoke test: drives the real menus (world, units, equip, shop with quantity, pub) and a full story battle
// through the same handlers a tap would use, then checks save/reload. Run (server on :8765):
//   NODE_PATH=$(npm root -g) node tests/smoke.js [url]
const { chromium } = require('playwright');
const URL = process.argv[2] || 'http://localhost:8765/';
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 800 } });
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  const ev = f => p.evaluate(f);
  await p.goto(URL);
  await p.click('[data-a=newgame]');
  await p.click('[data-a=startgame]');
  await p.click('.mwin [data-a=close]'); // how-to-play
  await ev(() => { G.fast = true; });
  // Menu -> Units -> unit -> Equip: first tap highlights, second equips
  await p.click('[data-a=go][data-v=menu]');
  await p.click('[data-a=mm][data-v=units]');
  await p.click('[data-a=unit]');
  await p.click('[data-a=um][data-v=equip]');
  await p.click('[data-a=eqslot][data-v=w]');
  await p.click('[data-a=eqpick][data-v="-"]'); await p.click('[data-a=eqpick][data-v="-"]'); // remove
  if ((await ev(() => G.units[0].eq.w)) !== null) errs.push('remove failed');
  await p.click('[data-a=eqpick][data-v=ironsword]'); await p.click('[data-a=eqpick][data-v=ironsword]');
  if ((await ev(() => G.units[0].eq.w)) !== 'ironsword') errs.push('re-equip failed');
  await p.click('[data-a=eqback]'); await p.click('[data-a=go][data-v=unit]');
  await p.click('[data-a=um][data-v=abil]');
  await p.click('[data-a=abpick][data-v=focus]');
  await p.click('[data-a=go][data-v=unit]');
  await p.click('[data-a=um][data-v=job]');
  await p.click('[data-a=jobpick][data-v=knight]'); // locked: only highlights
  if ((await ev(() => G.units[0].job)) !== 'squire') errs.push('locked job changed');
  // Town -> Shop -> buy 2 daggers through the quantity window
  await ev(() => { S.sel = null; go('town'); });
  await p.click('[data-a=town][data-v=shop]');
  await p.click('[data-a=shopm][data-v=buy]');
  await p.click('[data-a=buyhl][data-v=dagger]'); await p.click('[data-a=buyhl][data-v=dagger]');
  await p.click('[data-a=qty][data-v="1"]');
  await p.click('[data-a=qtyok]');
  if ((await ev(() => G.inv.dagger)) !== 2 || (await ev(() => G.gil)) !== 560) errs.push('buy qty failed ' + (await ev(() => G.inv.dagger + '/' + G.gil)));
  await p.click('[data-a=shopm][data-v=menu]');
  await p.click('[data-a=shopm][data-v=sell]');
  await p.click('[data-a=sellhl][data-v="item:dagger"]'); await p.click('[data-a=sellhl][data-v="item:dagger"]');
  await p.click('[data-a=qtyok]');
  if ((await ev(() => G.inv.dagger)) !== 1) errs.push('sell failed');
  await p.click('[data-a=shopm][data-v=menu]');
  await p.click('[data-a=shopm][data-v=bazaar]');
  await ev(() => go('town'));
  // Pub: accept mission with two taps
  await p.click('[data-a=town][data-v=pub]');
  await p.click('[data-a=pubm][data-v=missions]');
  await p.click('[data-a=pubmis]'); await p.click('[data-a=pubmis]');
  if ((await ev(() => G.accepted)) !== 'm1') errs.push('mission not accepted');
  await ev(() => { S.sel = null; go('world'); });
  await p.click('g[data-v=briar]');
  await p.click('[data-a=travel]');
  await p.click('[data-a=deploy][data-v=mission]');
  await p.click('[data-a=fight]');
  await p.waitForSelector('.mwin [data-a=bok]');
  await p.click('[data-a=bok]');
  // One real canvas tap to move
  await p.waitForFunction(() => BS.mode === 'menu', null, { timeout: 30000 });
  await p.waitForFunction(() => !V.tween, null, { timeout: 5000 }); // camera has settled on the unit
  await p.click('[data-a=bmove]');
  const pt = await ev(() => {
    for (const [k, v] of BS.reach) if (v.d > 0) { const t = tileAt(B, v.x, v.y), [x, y] = iso(v.x, v.y, t.h); if (x > 20 && x < V.w - 20 && y > 120 && y < V.h - 220 && pickTile(x, y) + '' === v.x + ',' + v.y) return { x, y, tx: v.x, ty: v.y }; }
    return null;
  });
  if (pt) {
    const box = await p.locator('#bv').boundingBox();
    await p.mouse.click(box.x + pt.x, box.y + pt.y);
    await p.waitForFunction(() => BS.mode === 'menu' || BS.mode === 'face', null, { timeout: 5000 });
    const pos = await ev(() => [BS.actor.x, BS.actor.y]);
    if (pos[0] !== pt.tx || pos[1] !== pt.ty) errs.push('tap-move went to ' + pos + ' not ' + [pt.tx, pt.ty]);
  } else errs.push('no tappable move tile found');
  // Command menu through real buttons: Action -> Fight -> target preview
  await ev(() => { if (BS.mode === 'face') BACT.bface(String(BS.actor.f)); });
  // Let the AI drive the rest through the UI handlers
  const outcome = await ev(async () => {
    const wait = ms => new Promise(r => setTimeout(r, ms));
    for (let i = 0; i < 4000 && S.scr === 'battle'; i++) {
      if (document.querySelector('.mwin [data-a=bok]')) { BACT.bok(); await wait(50); continue; }
      if (BS.mode === 'menu') {
        const a = BS.actor, plan = aiPlan(B, a);
        if (!a.moved && (plan.x !== a.x || plan.y !== a.y) && canMove(a)) { BACT.bmove(); await doMove(plan.x, plan.y); continue; }
        if (plan.id && !a.acted) { startTargeting(plan.id); BS.center = [plan.cx, plan.cy]; showTargetPanel(); await doAct(); continue; }
        BACT.bwait();
      }
      if (BS.mode === 'face') BACT.bface(String(BS.actor.f));
      await wait(50);
    }
    return S.results && S.results.won;
  });
  console.log('battle won:', outcome, '| stage', await ev(() => G.stage), '| gil', await ev(() => G.gil));
  // Results screens
  for (let i = 0; i < 3 && (await ev(() => S.scr)) === 'results'; i++) { await p.click('[data-a=rnext],[data-a=recruit][data-v="0"]'); }
  await p.reload();
  await p.click('[data-a=continue]');
  const st = await ev(() => G && G.battles);
  if (st !== 1) errs.push('save/continue failed: battles=' + st);
  console.log(errs.length ? 'ERRORS:\n' + errs.join('\n') : 'smoke ok');
  await b.close();
  process.exit(errs.length ? 1 : 0);
})();
