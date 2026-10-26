// Hollowmark Tactics: game data. All names, maps and characters are original.
'use strict';

const RACES = {
  human:    { name: 'Human',    hp: 80, mp: 20, atk: 18, def: 12, mag: 16, res: 12, spd: 10, skin: '#e8c4a0', desc: 'Adaptable. The widest range of jobs.' },
  saurian:  { name: 'Saurian',  hp: 92, mp: 12, atk: 21, def: 15, mag: 10, res: 9,  spd: 9,  skin: '#7fa86a', desc: 'Scaled and sturdy. Hits hard, weak to magic.' },
  sylph:    { name: 'Sylph',    hp: 74, mp: 18, atk: 18, def: 10, mag: 17, res: 14, spd: 12, skin: '#f0d8c8', desc: 'Long-eared forest folk. Fast and precise.' },
  mossling: { name: 'Mossling', hp: 72, mp: 22, atk: 15, def: 11, mag: 18, res: 13, spd: 11, skin: '#c9d6a3', desc: 'Small, furry and clever with tools and beasts.' },
  nuwa:     { name: 'Nuwa',     hp: 70, mp: 28, atk: 12, def: 10, mag: 22, res: 16, spd: 9,  skin: '#b9a8d8', desc: 'Long-lived scholars. The strongest spellcasters.' },
};

// w: weapon types, body: armor types, head: headgear types, sh: can use shields
// mv/jp/ev: move, jump, evade. g: average stat growth per level. req: {job: abilities mastered}
const JOBS = {};
function J(id, name, races, o) { JOBS[id] = Object.assign({ id, name, races, req: {}, sh: false }, o); }
J('squire', 'Squire', ['human'], { w: ['sword'], body: ['heavy', 'light'], head: ['helm', 'hat'], sh: true, mv: 4, jp: 1, ev: 10, col: '#4f7bc4', g: { hp: 9, mp: 2, atk: 2, def: 1.6, mag: 1, res: 1, spd: .4 }, desc: 'Sturdy all-rounder. Learns basic battle skills.' });
J('archer', 'Archer', ['human', 'sylph'], { w: ['bow'], body: ['light'], head: ['hat'], mv: 4, jp: 2, ev: 15, col: '#5a9a52', g: { hp: 7, mp: 2, atk: 1.8, def: 1.2, mag: 1, res: 1.2, spd: .5 }, desc: 'Ranged attacks that cripple foes.' });
J('mender', 'Mender', ['human', 'sylph', 'nuwa'], { w: ['staff'], body: ['robe', 'light'], head: ['hat'], mv: 3, jp: 1, ev: 10, col: '#e6e2d0', g: { hp: 6, mp: 4, atk: 1, def: 1, mag: 2, res: 1.8, spd: .4 }, desc: 'Restorative magic: healing, revival, cures.' });
J('arcanist', 'Arcanist', ['human'], { w: ['rod'], body: ['robe'], head: ['hat'], mv: 3, jp: 1, ev: 8, col: '#3b3f8f', g: { hp: 5, mp: 4.5, atk: .8, def: .8, mag: 2.4, res: 1.6, spd: .4 }, desc: 'Elemental attack spells.' });
J('rogue', 'Rogue', ['human', 'mossling'], { w: ['knife'], body: ['light'], head: ['hat'], mv: 5, jp: 2, ev: 25, col: '#6b5a48', g: { hp: 6.5, mp: 1.5, atk: 1.7, def: 1.1, mag: .8, res: 1, spd: .6 }, desc: 'Steals gil and gear. Hard to hit.' });
J('knight', 'Knight', ['human'], { w: ['greatsword', 'sword'], body: ['heavy'], head: ['helm'], sh: true, mv: 3, jp: 1, ev: 10, col: '#a9b0bc', req: { squire: 2 }, g: { hp: 11, mp: 2, atk: 2.2, def: 2.2, mag: .8, res: 1.2, spd: .3 }, desc: 'Armored front-liner that breaks enemy stats.' });
J('spellblade', 'Spellblade', ['human'], { w: ['sword'], body: ['light', 'heavy'], head: ['helm', 'hat'], mv: 4, jp: 1, ev: 12, col: '#8c4fb0', req: { squire: 2, arcanist: 1 }, g: { hp: 8, mp: 3, atk: 2.1, def: 1.4, mag: 1.6, res: 1.4, spd: .45 }, desc: 'Channels elements through the blade.' });
J('shadow', 'Shadow', ['human'], { w: ['knife', 'katana'], body: ['light'], head: ['hat'], mv: 5, jp: 3, ev: 30, col: '#2a2d3a', req: { rogue: 2, archer: 1 }, g: { hp: 7, mp: 2, atk: 2.1, def: 1, mag: 1.2, res: 1, spd: .7 }, desc: 'Fast striker with veils and binding arts.' });
J('warrior', 'Warrior', ['saurian'], { w: ['sword', 'greatsword'], body: ['heavy', 'light'], head: ['helm'], sh: true, mv: 4, jp: 1, ev: 8, col: '#b0543c', g: { hp: 10, mp: 1, atk: 2.3, def: 1.8, mag: .6, res: .9, spd: .35 }, desc: 'Saurian brawler with rallying cries.' });
J('wyrmlancer', 'Wyrmlancer', ['saurian'], { w: ['spear'], body: ['heavy'], head: ['helm'], mv: 4, jp: 3, ev: 8, col: '#3f6f8a', req: { warrior: 2 }, g: { hp: 10, mp: 1.5, atk: 2.4, def: 1.8, mag: 1, res: 1, spd: .35 }, desc: 'Leaps from the sky and breathes elements.' });
J('cleric', 'Cleric', ['saurian'], { w: ['mace', 'staff'], body: ['robe', 'light'], head: ['hat'], mv: 3, jp: 1, ev: 8, col: '#d8c27a', g: { hp: 8, mp: 3.5, atk: 1.4, def: 1.4, mag: 1.8, res: 1.6, spd: .35 }, desc: 'Saurian healer and protector.' });
J('brawler', 'Brawler', ['saurian'], { w: ['fist'], body: ['light'], head: ['helm', 'hat'], mv: 4, jp: 2, ev: 15, col: '#c78b3c', req: { warrior: 2, cleric: 1 }, g: { hp: 11, mp: 1, atk: 2.5, def: 1.6, mag: .7, res: 1, spd: .45 }, desc: 'Unarmed fighter who heals with chakra.' });
J('fencer', 'Fencer', ['sylph'], { w: ['rapier'], body: ['light'], head: ['hat'], mv: 5, jp: 2, ev: 25, col: '#c45a7a', g: { hp: 7, mp: 2, atk: 2, def: 1.1, mag: 1, res: 1.2, spd: .6 }, desc: 'Swift duelist with precise thrusts.' });
J('summoner', 'Summoner', ['sylph'], { w: ['staff'], body: ['robe'], head: ['hat'], mv: 3, jp: 1, ev: 10, col: '#4fa6a0', req: { mender: 2 }, g: { hp: 5.5, mp: 5, atk: .8, def: .9, mag: 2.6, res: 1.8, spd: .4 }, desc: 'Calls spirits that strike only enemies.' });
J('deadeye', 'Deadeye', ['sylph'], { w: ['greatbow', 'bow'], body: ['light'], head: ['hat'], mv: 4, jp: 2, ev: 15, col: '#2f5f3a', req: { archer: 2, fencer: 1 }, g: { hp: 7, mp: 2, atk: 2.2, def: 1.2, mag: 1, res: 1.2, spd: .5 }, desc: 'Long-range sniper with deadly arrows.' });
J('animist', 'Animist', ['mossling'], { w: ['mace', 'instrument'], body: ['light', 'robe'], head: ['hat'], mv: 4, jp: 1, ev: 15, col: '#9c7cc4', g: { hp: 7, mp: 3, atk: 1.4, def: 1.2, mag: 1.8, res: 1.6, spd: .45 }, desc: 'Calls on wild creatures to help.' });
J('gunner', 'Gunner', ['mossling'], { w: ['gun'], body: ['light'], head: ['hat'], mv: 3, jp: 1, ev: 10, col: '#7a5230', g: { hp: 6.5, mp: 2, atk: 2, def: 1, mag: 1, res: 1.2, spd: .4 }, desc: 'Longest-range attacks, ignores height.' });
J('tinker', 'Tinker', ['mossling'], { w: ['knife', 'instrument'], body: ['light'], head: ['hat'], mv: 4, jp: 2, ev: 20, col: '#d07a3a', req: { animist: 1, rogue: 1 }, g: { hp: 6.5, mp: 2, atk: 1.7, def: 1, mag: 1.2, res: 1.2, spd: .6 }, desc: 'Tricks and gadgets that slow and confuse.' });
J('mossknight', 'Moss Knight', ['mossling'], { w: ['greatsword', 'sword'], body: ['heavy'], head: ['helm'], sh: true, mv: 3, jp: 1, ev: 10, col: '#5d7a3a', req: { animist: 2 }, g: { hp: 10, mp: 2.5, atk: 2.1, def: 2, mag: 1.2, res: 1.4, spd: .35 }, desc: 'Tough little knight with thorned blades.' });
J('sage', 'Sage', ['nuwa'], { w: ['rod', 'staff'], body: ['robe'], head: ['hat'], mv: 3, jp: 1, ev: 8, col: '#3a7a8f', g: { hp: 5.5, mp: 4.5, atk: .8, def: .9, mag: 2.4, res: 1.8, spd: .4 }, desc: 'Water, wind and draining spells.' });
J('chronomancer', 'Chronomancer', ['nuwa'], { w: ['staff', 'rod'], body: ['robe'], head: ['hat'], mv: 3, jp: 1, ev: 10, col: '#b0905a', req: { sage: 2 }, g: { hp: 5.5, mp: 5, atk: .8, def: .9, mag: 2.2, res: 2, spd: .5 }, desc: 'Bends time: haste, slow and stop.' });
J('illusionist', 'Illusionist', ['nuwa'], { w: ['rod'], body: ['robe'], head: ['hat'], mv: 3, jp: 1, ev: 8, col: '#a04a8a', req: { sage: 2, chronomancer: 1 }, g: { hp: 5, mp: 5.5, atk: .7, def: .8, mag: 2.8, res: 1.8, spd: .4 }, desc: 'Wide spells that strike every foe in range.' });
J('alchemist', 'Alchemist', ['nuwa'], { w: ['staff'], body: ['robe'], head: ['hat'], mv: 3, jp: 1, ev: 8, col: '#7a8a3a', g: { hp: 6, mp: 4, atk: .9, def: 1, mag: 2.1, res: 1.8, spd: .4 }, desc: 'Brews, poisons and curses.' });

// Abilities. type A (action), R (reaction), S (support).
// fx: atk (weapon damage), mag (magic damage), heal, raise, buff, debuff (status only), cure, steal, drain, mpdmg, quick
// rng: 'w' = weapon range; 0 = self. aoe: radius. fo: only hits foes. hits: 'allies' only hits allies.
// cat: phys | mag | skill. st: statuses applied, ch: chance %. brk: stat breaks. ap: AP to master.
const AB = {};
function A(id, name, job, o) { AB[id] = Object.assign({ id, name, job, type: 'A', rng: 1, aoe: 0, mp: 0, cat: 'skill', tgt: 'foe', ap: 100 }, o); }
function R(id, name, job, ap, desc) { AB[id] = { id, name, job, type: 'R', ap, desc }; }
function Sp(id, name, job, ap, desc) { AB[id] = { id, name, job, type: 'S', ap, desc }; }

// Human
A('focus', 'Focus', 'squire', { fx: 'buff', rng: 0, tgt: 'self', st: ['boost'], ap: 80, desc: 'Next attack deals 1.5x damage.' });
A('firstaid', 'First Aid', 'squire', { fx: 'heal', pw: 20, rng: 1, tgt: 'ally', cure: ['poison', 'blind'], ap: 80, desc: 'Small heal and cures poison and blind.' });
A('rush', 'Rush', 'squire', { fx: 'atk', pw: 1.3, rng: 1, ap: 100, desc: 'A heavy charging blow.' });
A('stonetoss', 'Stone Toss', 'squire', { fx: 'atk', pw: .6, rng: 4, v: 99, ap: 60, desc: 'Throw a stone at a distant foe.' });
A('aimlegs', 'Aim: Legs', 'archer', { fx: 'atk', pw: .8, rng: 'w', st: ['immobilize'], ch: 70, ap: 100, desc: 'Damage and immobilize.' });
A('aimarm', 'Aim: Arm', 'archer', { fx: 'atk', pw: .8, rng: 'w', st: ['disable'], ch: 60, ap: 120, desc: 'Damage and disable actions.' });
A('blackout', 'Blackout', 'archer', { fx: 'atk', pw: .8, rng: 'w', st: ['blind'], ch: 70, ap: 100, desc: 'Damage and blind.' });
A('pierce', 'Piercing Shot', 'archer', { fx: 'atk', pw: 1.4, rng: 'w', ap: 150, desc: 'A powerful aimed shot.' });
A('cure', 'Cure', 'mender', { fx: 'heal', pw: 30, rng: 4, aoe: 1, mp: 6, cat: 'mag', tgt: 'ally', ap: 80, desc: 'Restores HP in a small area.' });
A('cura', 'Cura', 'mender', { fx: 'heal', pw: 60, rng: 4, aoe: 1, mp: 14, cat: 'mag', tgt: 'ally', ap: 180, desc: 'Restores more HP in a small area.' });
A('raise', 'Raise', 'mender', { fx: 'raise', pw: 25, rng: 3, mp: 12, cat: 'mag', tgt: 'ko', ap: 150, desc: 'Revives a fallen ally with 25% HP.' });
A('esuna', 'Esuna', 'mender', { fx: 'cure', rng: 4, aoe: 1, mp: 8, cat: 'mag', tgt: 'ally', cure: ['poison', 'blind', 'silence', 'sleep', 'slow', 'immobilize', 'disable', 'doom', 'stop'], ap: 120, desc: 'Removes negative statuses in an area.' });
A('fire', 'Fire', 'arcanist', { fx: 'mag', pw: 32, el: 'fire', rng: 4, aoe: 1, mp: 6, cat: 'mag', ap: 100, desc: 'Fire damage in a small area.' });
A('blizzard', 'Blizzard', 'arcanist', { fx: 'mag', pw: 32, el: 'ice', rng: 4, aoe: 1, mp: 6, cat: 'mag', ap: 100, desc: 'Ice damage in a small area.' });
A('thunder', 'Thunder', 'arcanist', { fx: 'mag', pw: 32, el: 'bolt', rng: 4, aoe: 1, mp: 6, cat: 'mag', ap: 100, desc: 'Lightning damage in a small area.' });
A('fira', 'Fira', 'arcanist', { fx: 'mag', pw: 58, el: 'fire', rng: 4, aoe: 1, mp: 16, cat: 'mag', ap: 250, desc: 'Strong fire damage in a small area.' });
A('stealgil', 'Steal: Gil', 'rogue', { fx: 'steal', what: 'gil', ap: 60, desc: 'Steal gil from a foe.' });
A('stealarmor', 'Steal: Armor', 'rogue', { fx: 'steal', what: 'b', ap: 150, desc: 'Steal body armor.' });
A('stealweapon', 'Steal: Weapon', 'rogue', { fx: 'steal', what: 'w', ap: 200, desc: 'Steal the equipped weapon.' });
A('stealacc', 'Steal: Accessory', 'rogue', { fx: 'steal', what: 'a', ap: 150, desc: 'Steal an accessory.' });
A('rendpow', 'Rend Power', 'knight', { fx: 'atk', pw: .9, brk: { atk: 5 }, ap: 150, desc: 'Damage and lower Attack.' });
A('rendarm', 'Rend Armor', 'knight', { fx: 'atk', pw: .9, brk: { def: 5 }, ap: 150, desc: 'Damage and lower Defense.' });
A('rendmag', 'Rend Magic', 'knight', { fx: 'atk', pw: .9, brk: { mag: 5 }, ap: 150, desc: 'Damage and lower Magic.' });
A('sentinel', 'Sentinel', 'knight', { fx: 'buff', rng: 1, tgt: 'ally', st: ['protect'], ap: 150, desc: 'Grant Protect to self or an adjacent ally.' });
A('flamedge', 'Flame Edge', 'spellblade', { fx: 'atk', pw: 1.15, el: 'fire', mp: 4, ap: 150, desc: 'Fire-charged strike.' });
A('frostedge', 'Frost Edge', 'spellblade', { fx: 'atk', pw: 1.15, el: 'ice', mp: 4, ap: 150, desc: 'Ice-charged strike.' });
A('voltedge', 'Volt Edge', 'spellblade', { fx: 'atk', pw: 1.15, el: 'bolt', mp: 4, ap: 150, desc: 'Lightning-charged strike.' });
A('manasiphon', 'Mana Siphon', 'spellblade', { fx: 'mpdmg', pw: 14, drainmp: true, ap: 200, desc: 'Drain MP from an adjacent foe.' });
A('shuriken', 'Shuriken', 'shadow', { fx: 'atk', pw: 1, rng: 4, v: 99, ap: 150, desc: 'Throw a star at a distant foe.' });
A('flameveil', 'Flame Veil', 'shadow', { fx: 'mag', pw: 38, el: 'fire', rng: 3, aoe: 1, mp: 8, ap: 200, desc: 'Fire damage in a small area.' });
A('shadowbind', 'Shadowbind', 'shadow', { fx: 'debuff', rng: 3, st: ['stop'], ch: 45, mp: 6, ap: 250, desc: 'Chance to Stop a foe.' });
A('mirrorstep', 'Mirror Step', 'shadow', { fx: 'buff', rng: 0, tgt: 'self', st: ['haste'], ap: 200, desc: 'Grant Haste to self.' });
// Saurian
A('cleave', 'Cleave', 'warrior', { fx: 'atk', pw: .9, rng: 0, aoe: 1, fo: true, ap: 120, desc: 'Strike every adjacent foe.' });
A('rendspd', 'Rend Speed', 'warrior', { fx: 'atk', pw: .9, brk: { spd: 2 }, ap: 120, desc: 'Damage and lower Speed.' });
A('warcry', 'War Cry', 'warrior', { fx: 'buff', rng: 0, aoe: 2, hits: 'allies', tgt: 'self', st: ['boost'], ap: 150, desc: 'Boost nearby allies.' });
A('bulwark', 'Bulwark', 'warrior', { fx: 'buff', rng: 0, tgt: 'self', st: ['protect', 'shell'], ap: 150, desc: 'Grant Protect and Shell to self.' });
A('jump', 'Jump', 'wyrmlancer', { fx: 'atk', pw: 1.6, rng: 4, v: 99, ap: 200, desc: 'Leap and strike from above.' });
A('firebreath', 'Fire Breath', 'wyrmlancer', { fx: 'mag', pw: 40, el: 'fire', rng: 3, aoe: 1, ap: 150, desc: 'Breathe fire on an area.' });
A('icebreath', 'Ice Breath', 'wyrmlancer', { fx: 'mag', pw: 40, el: 'ice', rng: 3, aoe: 1, ap: 150, desc: 'Breathe frost on an area.' });
A('boltbreath', 'Bolt Breath', 'wyrmlancer', { fx: 'mag', pw: 40, el: 'bolt', rng: 3, aoe: 1, ap: 150, desc: 'Breathe lightning on an area.' });
A('mend', 'Mend', 'cleric', { fx: 'heal', pw: 40, rng: 3, mp: 8, cat: 'mag', tgt: 'ally', ap: 100, desc: 'Restores HP to one ally.' });
A('purify', 'Purify', 'cleric', { fx: 'cure', rng: 3, aoe: 1, mp: 6, cat: 'mag', tgt: 'ally', cure: ['poison', 'blind', 'silence', 'sleep', 'slow', 'immobilize', 'disable'], ap: 100, desc: 'Removes negative statuses in an area.' });
A('barrier', 'Barrier', 'cleric', { fx: 'buff', rng: 3, mp: 10, cat: 'mag', tgt: 'ally', st: ['protect', 'shell'], ap: 150, desc: 'Grant Protect and Shell.' });
A('regen', 'Regen', 'cleric', { fx: 'buff', rng: 3, mp: 8, cat: 'mag', tgt: 'ally', st: ['regen'], ap: 120, desc: 'Restores HP each turn.' });
A('chakra', 'Chakra', 'brawler', { fx: 'heal', pw: 26, rng: 0, aoe: 1, hits: 'allies', tgt: 'self', ap: 150, desc: 'Heal self and adjacent allies.' });
A('earthsmash', 'Earth Smash', 'brawler', { fx: 'atk', pw: 1.1, el: 'earth', rng: 1, aoe: 1, fo: true, ap: 200, desc: 'Shockwave that hits foes in an area.' });
A('revive', 'Revive', 'brawler', { fx: 'raise', pw: 50, rng: 1, tgt: 'ko', ap: 250, desc: 'Revive an adjacent ally with 50% HP.' });
A('ironbody', 'Iron Body', 'brawler', { fx: 'buff', rng: 0, tgt: 'self', st: ['protect', 'regen'], ap: 150, desc: 'Grant Protect and Regen to self.' });
// Sylph
A('lunge', 'Lunge', 'fencer', { fx: 'atk', pw: 1.25, rng: 2, line: true, ap: 120, desc: 'Thrust that reaches 2 tiles.' });
A('swallowtail', 'Swallowtail', 'fencer', { fx: 'atk', pw: .9, rng: 0, aoe: 1, fo: true, ap: 150, desc: 'Strike every adjacent foe.' });
A('feint', 'Feint', 'fencer', { fx: 'atk', pw: .7, st: ['slow'], ch: 70, ap: 120, desc: 'Damage and Slow.' });
A('piercer', 'Piercer', 'fencer', { fx: 'atk', pw: 1.2, pierce: true, ap: 200, desc: 'Ignores Defense and Protect.' });
A('salamander', 'Salamander', 'summoner', { fx: 'mag', pw: 48, el: 'fire', rng: 4, aoe: 1, fo: true, mp: 18, cat: 'mag', ap: 200, desc: 'Fire spirit. Hits foes only.' });
A('undine', 'Undine', 'summoner', { fx: 'heal', pw: 40, rng: 4, aoe: 1, hits: 'allies', mp: 14, cat: 'mag', tgt: 'ally', ap: 200, desc: 'Water spirit. Heals allies only.' });
A('sylphid', 'Sylphid', 'summoner', { fx: 'mag', pw: 42, el: 'wind', rng: 4, aoe: 1, fo: true, st: ['slow'], ch: 40, mp: 18, cat: 'mag', ap: 250, desc: 'Wind spirit. Hits foes only; may Slow.' });
A('lumen', 'Lumen', 'summoner', { fx: 'mag', pw: 68, el: 'holy', rng: 4, aoe: 1, fo: true, mp: 28, cat: 'mag', ap: 350, desc: 'Spirit of light. Hits foes only.' });
A('twinshot', 'Twinshot', 'deadeye', { fx: 'atk', pw: .75, hitsN: 2, rng: 'w', ap: 200, desc: 'Two quick shots.' });
A('doomarrow', 'Doom Arrow', 'deadeye', { fx: 'atk', pw: .6, rng: 'w', st: ['doom'], ch: 40, ap: 300, desc: 'Damage and Doom (KO in 3 turns).' });
A('lullarrow', 'Lull Arrow', 'deadeye', { fx: 'atk', pw: .6, rng: 'w', st: ['sleep'], ch: 60, ap: 200, desc: 'Damage and Sleep.' });
A('longshot', 'Longshot', 'deadeye', { fx: 'atk', pw: 1, rng: 8, v: 99, ap: 200, desc: 'A shot with extreme range.' });
// Mossling
A('lullaby', 'Lullaby', 'animist', { fx: 'debuff', rng: 3, aoe: 1, fo: true, st: ['sleep'], ch: 55, ap: 120, desc: 'Puts foes in an area to Sleep.' });
A('woolguard', 'Woolguard', 'animist', { fx: 'buff', rng: 3, tgt: 'ally', st: ['protect', 'shell'], ap: 150, desc: 'Grant Protect and Shell.' });
A('hearthsong', 'Hearth Song', 'animist', { fx: 'buff', rng: 0, aoe: 2, hits: 'allies', tgt: 'self', st: ['regen'], ap: 150, desc: 'Grant Regen to nearby allies.' });
A('stampede', 'Stampede', 'animist', { fx: 'mag', pw: 34, el: 'earth', rng: 4, aoe: 1, fo: true, ap: 200, desc: 'A herd tramples foes in an area.' });
A('scorch', 'Scorch Round', 'gunner', { fx: 'atk', pw: 1, el: 'fire', rng: 'w', ap: 150, desc: 'Fire-element shot.' });
A('silencer', 'Silencer', 'gunner', { fx: 'atk', pw: .7, rng: 'w', st: ['silence'], ch: 70, ap: 120, desc: 'Damage and Silence.' });
A('stunround', 'Stun Round', 'gunner', { fx: 'atk', pw: .7, rng: 'w', st: ['disable'], ch: 50, ap: 150, desc: 'Damage and disable actions.' });
A('chargeshot', 'Charge Shot', 'gunner', { fx: 'atk', pw: 1.5, rng: 'w', ap: 250, desc: 'A powerful charged shot.' });
A('toss', 'Toss', 'tinker', { fx: 'atk', pw: .9, rng: 4, v: 99, ap: 100, desc: 'Throw a blade at range.' });
A('jitter', 'Jitter', 'tinker', { fx: 'debuff', rng: 3, aoe: 1, fo: true, st: ['slow'], ch: 60, ap: 150, desc: 'Slow foes in an area.' });
A('pratfall', 'Pratfall', 'tinker', { fx: 'debuff', rng: 3, st: ['immobilize'], ch: 70, ap: 120, desc: 'Trip a foe so it cannot move.' });
A('encore', 'Encore', 'tinker', { fx: 'buff', rng: 3, tgt: 'ally', st: ['haste'], ap: 250, desc: 'Grant Haste to an ally.' });
A('mossrush', 'Moss Rush', 'mossknight', { fx: 'atk', pw: 1.4, ap: 150, desc: 'A heavy charging blow.' });
A('mossguard', 'Mossguard', 'mossknight', { fx: 'buff', rng: 0, tgt: 'self', st: ['protect', 'shell'], ap: 150, desc: 'Grant Protect and Shell to self.' });
A('mossaid', 'Moss Aid', 'mossknight', { fx: 'heal', pw: 32, rng: 1, tgt: 'ally', ap: 120, desc: 'Heal self or an adjacent ally.' });
A('thornburst', 'Thornburst', 'mossknight', { fx: 'atk', pw: .9, rng: 0, aoe: 1, fo: true, st: ['poison'], ch: 50, ap: 200, desc: 'Thorns hit adjacent foes and may poison.' });
// Nuwa
A('aqua', 'Aqua', 'sage', { fx: 'mag', pw: 34, el: 'water', rng: 4, aoe: 1, mp: 6, cat: 'mag', ap: 100, desc: 'Water damage in a small area.' });
A('aero', 'Aero', 'sage', { fx: 'mag', pw: 34, el: 'wind', rng: 4, aoe: 1, mp: 6, cat: 'mag', ap: 100, desc: 'Wind damage in a small area.' });
A('bio', 'Bio', 'sage', { fx: 'mag', pw: 26, el: 'dark', rng: 4, aoe: 1, st: ['poison'], ch: 60, mp: 10, cat: 'mag', ap: 150, desc: 'Dark damage that may poison.' });
A('drain', 'Drain', 'sage', { fx: 'drain', pw: 32, el: 'dark', rng: 4, mp: 10, cat: 'mag', ap: 180, desc: 'Steal HP from a foe.' });
A('haste', 'Haste', 'chronomancer', { fx: 'buff', rng: 4, mp: 10, cat: 'mag', tgt: 'ally', st: ['haste'], ap: 150, desc: 'Turns come faster.' });
A('slow', 'Slow', 'chronomancer', { fx: 'debuff', rng: 4, aoe: 1, mp: 8, cat: 'mag', st: ['slow'], ch: 70, ap: 120, desc: 'Turns come slower.' });
A('stop', 'Stop', 'chronomancer', { fx: 'debuff', rng: 4, mp: 16, cat: 'mag', st: ['stop'], ch: 45, ap: 250, desc: 'Chance to freeze a foe in time.' });
A('quicken', 'Quicken', 'chronomancer', { fx: 'quick', rng: 3, mp: 20, cat: 'mag', tgt: 'ally', ap: 350, desc: 'An ally takes the next turn.' });
A('prominence', 'Prominence', 'illusionist', { fx: 'mag', pw: 30, el: 'fire', rng: 6, aoe: 2, fo: true, mp: 20, cat: 'mag', ap: 250, desc: 'Fire on every foe in a wide area.' });
A('glacier', 'Glacier', 'illusionist', { fx: 'mag', pw: 30, el: 'ice', rng: 6, aoe: 2, fo: true, mp: 20, cat: 'mag', ap: 250, desc: 'Ice on every foe in a wide area.' });
A('tempest', 'Tempest', 'illusionist', { fx: 'mag', pw: 30, el: 'wind', rng: 6, aoe: 2, fo: true, mp: 20, cat: 'mag', ap: 250, desc: 'Wind on every foe in a wide area.' });
A('starcross', 'Star Cross', 'illusionist', { fx: 'mag', pw: 38, el: 'holy', rng: 6, aoe: 2, fo: true, mp: 30, cat: 'mag', ap: 400, desc: 'Holy light on every foe in a wide area.' });
A('salvemix', 'Salve Mix', 'alchemist', { fx: 'heal', pw: 36, rng: 3, tgt: 'ally', cure: ['poison'], ap: 100, desc: 'Brewed salve: heals and cures poison.' });
A('poisoncloud', 'Poison Cloud', 'alchemist', { fx: 'debuff', rng: 3, aoe: 1, mp: 6, cat: 'mag', st: ['poison'], ch: 80, ap: 100, desc: 'Poison everything in an area.' });
A('rasp', 'Rasp', 'alchemist', { fx: 'mpdmg', pw: 22, rng: 4, mp: 4, cat: 'mag', ap: 120, desc: 'Damages MP.' });
A('hourglass', 'Hourglass Hex', 'alchemist', { fx: 'debuff', rng: 4, mp: 16, cat: 'mag', st: ['doom'], ch: 45, ap: 300, desc: 'Doom: KO in 3 turns.' });

R('counter', 'Counter', 'warrior', 200, 'Strike back when hit by an adjacent attack.');
R('autopotion', 'Auto-Potion', 'squire', 150, 'Drink a Potion when damaged (uses inventory).');
R('dodge', 'Dodge', 'rogue', 150, 'Evade +15.');
R('returnfire', 'Return Fire', 'archer', 200, 'Shoot back at ranged attackers in range.');
R('laststand', 'Last Stand', 'knight', 250, 'Below 25% HP, gain Boost and Protect.');
R('manashield', 'Mana Shield', 'sage', 250, 'Damage is taken from MP first.');
R('absorbmp', 'Absorb MP', 'arcanist', 200, 'Gain MP equal to the cost of spells cast on you.');
R('bonecrusher', 'Bonecrusher', 'brawler', 300, 'Counter adjacent attacks for 1.5x damage.');
Sp('watkup', 'Weapon Atk+', 'warrior', 200, 'Physical damage x1.2.');
Sp('magpowup', 'Magic Pow+', 'arcanist', 200, 'Magic damage and healing x1.2.');
Sp('concentrate', 'Concentrate', 'archer', 200, 'Accuracy +25.');
Sp('halfmp', 'Half MP', 'sage', 300, 'Abilities cost half MP.');
Sp('itemlore', 'Item Lore', 'alchemist', 150, 'Items are 1.5x as effective.');
Sp('shieldbearer', 'Shieldbearer', 'knight', 200, 'Equip shields in any job.');
Sp('expup', 'Exp Boost', 'mender', 150, 'Earn 1.5x EXP.');
Sp('fleet', 'Fleetfoot', 'rogue', 300, 'Move +1.');

// Monster abilities (not learnable)
A('m_punch', 'Grim Punch', null, { fx: 'atk', pw: 1.35, ap: 0, desc: '' });
A('m_bite', 'Venom Bite', null, { fx: 'atk', pw: 1, st: ['poison'], ch: 50, ap: 0, desc: '' });
A('m_howl', 'Howl', null, { fx: 'buff', rng: 0, aoe: 2, hits: 'allies', tgt: 'self', st: ['boost'], ap: 0, desc: '' });
A('m_sludge', 'Sludge', null, { fx: 'mag', pw: 26, el: 'water', rng: 3, st: ['slow'], ch: 40, mp: 4, cat: 'mag', ap: 0, desc: '' });
A('m_pit', 'Sand Pit', null, { fx: 'debuff', rng: 2, aoe: 1, fo: true, st: ['immobilize'], ch: 60, ap: 0, desc: '' });
A('m_crush', 'Mandible', null, { fx: 'atk', pw: 1.3, ap: 0, desc: '' });
A('m_hex', 'Bog Hex', null, { fx: 'debuff', rng: 4, aoe: 1, fo: true, st: ['sleep'], ch: 50, mp: 8, cat: 'mag', ap: 0, desc: '' });
A('m_mire', 'Mire Bolt', null, { fx: 'mag', pw: 34, el: 'dark', rng: 4, aoe: 1, mp: 8, cat: 'mag', ap: 0, desc: '' });
A('m_leech', 'Leech', null, { fx: 'drain', pw: 30, el: 'dark', rng: 3, mp: 6, cat: 'mag', ap: 0, desc: '' });

const STATUS = {
  poison: { name: 'Poison', bad: 1, t: 4, col: '#8fd05a' }, regen: { name: 'Regen', t: 4, col: '#7ee0a0' },
  sleep: { name: 'Sleep', bad: 1, t: 2, col: '#b0a0e0' }, silence: { name: 'Silence', bad: 1, t: 3, col: '#c0c0c0' },
  blind: { name: 'Blind', bad: 1, t: 3, col: '#808080' }, slow: { name: 'Slow', bad: 1, t: 3, col: '#c0a060' },
  haste: { name: 'Haste', t: 3, col: '#f0d060' }, stop: { name: 'Stop', bad: 1, t: 2, col: '#60a0e0' },
  protect: { name: 'Protect', t: 4, col: '#e0c060' }, shell: { name: 'Shell', t: 4, col: '#60c0e0' },
  immobilize: { name: 'Immobilize', bad: 1, t: 2, col: '#d08040' }, disable: { name: 'Disable', bad: 1, t: 2, col: '#d06060' },
  doom: { name: 'Doom', bad: 1, t: 3, col: '#a040a0' }, boost: { name: 'Boost', t: 3, col: '#ff9050' },
};
const ELEMENTS = { fire: '#ff7040', ice: '#80d0ff', bolt: '#ffe060', water: '#4090ff', wind: '#a0f0a0', earth: '#c09050', holy: '#fff6c0', dark: '#a060d0' };

// Weapon types: range and vertical reach
const WTYPES = {
  sword: { name: 'Sword', r: 1, v: 2 }, greatsword: { name: 'Greatsword', r: 1, v: 2 }, knife: { name: 'Knife', r: 1, v: 2 },
  rapier: { name: 'Rapier', r: 1, v: 2 }, katana: { name: 'Katana', r: 1, v: 2 }, fist: { name: 'Knuckles', r: 1, v: 2 },
  mace: { name: 'Mace', r: 1, v: 2 }, staff: { name: 'Staff', r: 1, v: 2 }, rod: { name: 'Rod', r: 1, v: 2 },
  instrument: { name: 'Instrument', r: 1, v: 2 }, spear: { name: 'Spear', r: 2, v: 3, line: true },
  bow: { name: 'Bow', r: 5, v: 99 }, greatbow: { name: 'Greatbow', r: 6, v: 99 }, gun: { name: 'Gun', r: 7, v: 99 },
  claw: { name: 'Claws', r: 1, v: 2 },
};

// Equipment. slot: w (weapon), o (shield), h (head), b (body), a (accessory). t: type.
// st: stage when it appears in the shop (0 = start, 1-3 after each story mission, 9 = Bazaar only).
const ITEMS = {};
function I(id, name, slot, t, price, st, stats, teach, extra) { ITEMS[id] = Object.assign({ id, name, slot, t, price, st, stats, teach: teach || [] }, extra || {}); }
// swords
I('shortsword', 'Short Sword', 'w', 'sword', 120, 0, { atk: 10 }, ['firstaid', 'stonetoss']);
I('ironsword', 'Iron Sword', 'w', 'sword', 220, 0, { atk: 12 }, ['focus', 'rush']);
I('cleaver', 'Hunter Cleaver', 'w', 'sword', 240, 0, { atk: 13 }, ['cleave', 'warcry']);
I('flamesaber', 'Flame Saber', 'w', 'sword', 900, 2, { atk: 16 }, ['flamedge'], { el: 'fire' });
I('frostbrand', 'Frost Brand', 'w', 'sword', 1100, 9, { atk: 17 }, ['frostedge', 'counter'], { el: 'ice' });
I('voltsaber', 'Volt Saber', 'w', 'sword', 1300, 3, { atk: 18 }, ['voltedge', 'manasiphon'], { el: 'bolt' });
I('mossbrand', 'Moss Brand', 'w', 'sword', 520, 1, { atk: 14 }, ['mossrush', 'mossaid']);
// greatswords
I('bastard', 'Bastard Sword', 'w', 'greatsword', 600, 1, { atk: 17 }, ['rendspd', 'bulwark']);
I('knightblade', 'Knight Blade', 'w', 'greatsword', 700, 1, { atk: 18 }, ['rendpow', 'sentinel']);
I('defender', 'Defender', 'w', 'greatsword', 1500, 3, { atk: 22, def: 3 }, ['rendarm', 'rendmag']);
I('thornclay', 'Thorn Claymore', 'w', 'greatsword', 1000, 2, { atk: 19 }, ['thornburst', 'mossguard']);
// knives / katana
I('dagger', 'Dagger', 'w', 'knife', 120, 0, { atk: 9 }, ['stealgil', 'stealarmor']);
I('kris', 'Kris', 'w', 'knife', 480, 1, { atk: 12, spd: 1 }, ['stealweapon', 'stealacc']);
I('jesterknife', 'Jester Knife', 'w', 'knife', 420, 1, { atk: 11 }, ['toss', 'pratfall']);
I('fangknife', 'Fang Knife', 'w', 'knife', 800, 9, { atk: 14, spd: 1 }, ['shuriken', 'mirrorstep']);
I('ashkatana', 'Ash Katana', 'w', 'katana', 1400, 3, { atk: 20 }, ['flameveil', 'shadowbind']);
// bows
I('huntbow', 'Hunting Bow', 'w', 'bow', 200, 0, { atk: 10 }, ['aimlegs', 'blackout']);
I('compbow', 'Composite Bow', 'w', 'bow', 560, 1, { atk: 13 }, ['aimarm', 'pierce']);
I('longbow', 'Longbow', 'w', 'greatbow', 900, 2, { atk: 15 }, ['twinshot', 'longshot']);
I('nightbow', 'Nightbow', 'w', 'greatbow', 1400, 9, { atk: 18 }, ['doomarrow', 'lullarrow']);
// staves / maces / rods
I('oakstaff', 'Oak Staff', 'w', 'staff', 150, 0, { atk: 5, mag: 2 }, ['cure', 'esuna']);
I('whitestaff', 'White Staff', 'w', 'staff', 650, 1, { atk: 6, mag: 4 }, ['cura', 'raise']);
I('emberstaff', 'Ember Staff', 'w', 'staff', 700, 1, { atk: 6, mag: 4 }, ['salamander', 'undine']);
I('galestaff', 'Gale Staff', 'w', 'staff', 1100, 2, { atk: 7, mag: 5 }, ['sylphid']);
I('lumenstaff', 'Lumen Staff', 'w', 'staff', 1800, 9, { atk: 8, mag: 7 }, ['lumen', 'expup']);
I('hourstaff', 'Hour Staff', 'w', 'staff', 650, 1, { atk: 6, mag: 4 }, ['haste', 'slow']);
I('stillstaff', 'Stilled Staff', 'w', 'staff', 1500, 9, { atk: 7, mag: 6 }, ['stop', 'quicken']);
I('mortar', 'Mortar Staff', 'w', 'staff', 180, 0, { atk: 5, mag: 2 }, ['salvemix', 'poisoncloud']);
I('alembic', 'Alembic Staff', 'w', 'staff', 900, 2, { atk: 6, mag: 5 }, ['rasp', 'hourglass']);
I('pilgrim', 'Pilgrim Mace', 'w', 'mace', 200, 0, { atk: 11, mag: 1 }, ['mend', 'purify']);
I('ironmace', 'Iron Mace', 'w', 'mace', 600, 1, { atk: 14, mag: 2 }, ['barrier', 'regen']);
I('emberrod', 'Ember Rod', 'w', 'rod', 180, 0, { atk: 4, mag: 3 }, ['fire', 'blizzard']);
I('stormrod', 'Storm Rod', 'w', 'rod', 600, 1, { atk: 5, mag: 4 }, ['thunder', 'absorbmp']);
I('blazerod', 'Blaze Rod', 'w', 'rod', 1200, 2, { atk: 5, mag: 6 }, ['fira', 'magpowup'], { el: 'fire' });
I('tiderod', 'Tide Rod', 'w', 'rod', 180, 0, { atk: 4, mag: 3 }, ['aqua', 'aero']);
I('bogrod', 'Bog Rod', 'w', 'rod', 650, 1, { atk: 5, mag: 4 }, ['bio', 'drain']);
I('prismrod', 'Prism Rod', 'w', 'rod', 1300, 2, { atk: 5, mag: 6 }, ['prominence', 'glacier']);
I('miragerod', 'Mirage Rod', 'w', 'rod', 2000, 9, { atk: 6, mag: 8 }, ['tempest', 'starcross']);
// spears, fists, rapiers, guns, instruments
I('partisan', 'Partisan', 'w', 'spear', 700, 1, { atk: 15 }, ['jump', 'firebreath']);
I('wyrmspear', 'Wyrm Spear', 'w', 'spear', 1500, 9, { atk: 19 }, ['icebreath', 'boltbreath']);
I('cestus', 'Cestus', 'w', 'fist', 220, 0, { atk: 12 }, ['chakra', 'earthsmash']);
I('ironknuckle', 'Iron Knuckle', 'w', 'fist', 1000, 2, { atk: 16 }, ['revive', 'ironbody']);
I('fleuret', 'Fleuret', 'w', 'rapier', 220, 0, { atk: 11 }, ['lunge', 'feint']);
I('estoc', 'Estoc', 'w', 'rapier', 640, 1, { atk: 14 }, ['swallowtail', 'piercer']);
I('flintlock', 'Flintlock', 'w', 'gun', 260, 0, { atk: 12 }, ['scorch', 'silencer']);
I('repeater', 'Repeater', 'w', 'gun', 1100, 2, { atk: 16 }, ['stunround', 'chargeshot']);
I('reedpipe', 'Reed Pipe', 'w', 'instrument', 200, 0, { atk: 6, mag: 2 }, ['lullaby', 'woolguard']);
I('herdhorn', 'Herd Horn', 'w', 'instrument', 600, 1, { atk: 8, mag: 3 }, ['hearthsong', 'stampede']);
I('jinglelute', 'Jingle Lute', 'w', 'instrument', 700, 1, { atk: 8, mag: 3 }, ['jitter', 'encore']);
// shields
I('buckler', 'Buckler', 'o', 'shield', 150, 0, { def: 2, ev: 8 }, []);
I('kiteshield', 'Kite Shield', 'o', 'shield', 600, 1, { def: 4, ev: 12 }, ['shieldbearer']);
// head
I('ironhelm', 'Iron Helm', 'h', 'helm', 160, 0, { def: 3, hp: 8 }, ['watkup']);
I('greathelm', 'Great Helm', 'h', 'helm', 700, 2, { def: 5, hp: 18 }, []);
I('feathercap', 'Feather Cap', 'h', 'hat', 140, 0, { def: 1, spd: 1 }, ['fleet']);
I('wizardhat', 'Wizard Hat', 'h', 'hat', 500, 1, { def: 2, mag: 3, mp: 6 }, ['halfmp']);
// body
I('bronzeplate', 'Bronze Plate', 'b', 'heavy', 260, 0, { def: 8, hp: 10 }, ['counter']);
I('knightmail', 'Knight Mail', 'b', 'heavy', 900, 1, { def: 12, hp: 18 }, ['laststand']);
I('leathervest', 'Leather Vest', 'b', 'light', 160, 0, { def: 5, ev: 3 }, ['dodge', 'autopotion']);
I('rangercoat', 'Ranger Coat', 'b', 'light', 520, 1, { def: 7, ev: 5 }, ['returnfire', 'concentrate']);
I('studjerkin', 'Studded Jerkin', 'b', 'light', 900, 2, { def: 9, hp: 10 }, ['bonecrusher']);
I('linenrobe', 'Linen Robe', 'b', 'robe', 150, 0, { def: 3, res: 3, mp: 4 }, ['expup', 'itemlore']);
I('magerobe', 'Mage Robe', 'b', 'robe', 600, 1, { def: 4, mag: 3, res: 4, mp: 8 }, ['absorbmp', 'magpowup']);
I('sagerobe', 'Sage Robe', 'b', 'robe', 900, 2, { def: 5, mag: 2, res: 6, mp: 10 }, ['manashield', 'halfmp']);
// accessories
I('powerwrist', 'Power Wrist', 'a', 'acc', 400, 1, { atk: 3 }, ['watkup']);
I('sageearring', 'Sage Earring', 'a', 'acc', 400, 1, { mag: 3 }, ['magpowup']);
I('swiftband', 'Swift Band', 'a', 'acc', 1200, 9, { mv: 1 }, ['fleet']);
I('springboots', 'Spring Boots', 'a', 'acc', 700, 2, { jp: 1, ev: 3 }, []);
I('charmring', 'Charm Ring', 'a', 'acc', 300, 0, { res: 3, hp: 6 }, ['concentrate']);

// Consumables (battle "Item" command)
const CONS = {
  potion: { name: 'Potion', price: 40, st: 0, fx: 'heal', pw: 50, desc: 'Restore 50 HP.' },
  hipotion: { name: 'Hi-Potion', price: 120, st: 1, fx: 'heal', pw: 120, desc: 'Restore 120 HP.' },
  ether: { name: 'Ether', price: 160, st: 1, fx: 'mp', pw: 30, desc: 'Restore 30 MP.' },
  phoenix: { name: 'Phoenix Down', price: 200, st: 0, fx: 'raise', pw: 25, desc: 'Revive with 25% HP.' },
  antidote: { name: 'Antidote', price: 30, st: 0, fx: 'cure', cure: ['poison'], desc: 'Cures Poison.' },
  eyedrops: { name: 'Eye Drops', price: 30, st: 0, fx: 'cure', cure: ['blind'], desc: 'Cures Blind.' },
  echoherb: { name: 'Echo Herb', price: 40, st: 1, fx: 'cure', cure: ['silence'], desc: 'Cures Silence.' },
  remedy: { name: 'Remedy', price: 250, st: 2, fx: 'cure', cure: ['poison', 'blind', 'silence', 'sleep', 'slow', 'immobilize', 'disable', 'doom', 'stop'], desc: 'Cures all negative statuses.' },
};

// Loot: dropped by enemies, combined at the Bazaar.
const LOOT = {
  wolfpelt: { name: 'Wolf Pelt', price: 30 }, grimfang: { name: 'Grimkin Fang', price: 25 }, emberstone: { name: 'Ember Stone', price: 60 },
  quarryore: { name: 'Quarry Ore', price: 50 }, oozegel: { name: 'Ooze Gel', price: 40 }, miremoss: { name: 'Mire Moss', price: 40 },
  hagcharm: { name: 'Hag Charm', price: 150 }, maw: { name: 'Sandmaw Plate', price: 70 }, silkthread: { name: 'Silk Thread', price: 45 },
};

// Bazaar: combine loot to create an item. The result is also added to the shop permanently.
const RECIPES = [
  { id: 'r1', out: 'fangknife', need: { wolfpelt: 1, grimfang: 2 }, gil: 200 },
  { id: 'r2', out: 'frostbrand', need: { quarryore: 2, oozegel: 1 }, gil: 300 },
  { id: 'r3', out: 'swiftband', need: { wolfpelt: 2, silkthread: 1 }, gil: 300 },
  { id: 'r4', out: 'nightbow', need: { silkthread: 2, miremoss: 1 }, gil: 400 },
  { id: 'r5', out: 'wyrmspear', need: { emberstone: 1, quarryore: 2, maw: 1 }, gil: 400 },
  { id: 'r6', out: 'stillstaff', need: { hagcharm: 1, miremoss: 1 }, gil: 400 },
  { id: 'r7', out: 'lumenstaff', need: { hagcharm: 1, emberstone: 1, silkthread: 1 }, gil: 500 },
  { id: 'r8', out: 'miragerod', need: { hagcharm: 1, oozegel: 2, maw: 1 }, gil: 600 },
];

// Monsters
const MONSTERS = {
  grimkin: { name: 'Grimkin', hp: 70, mp: 0, atk: 22, def: 10, mag: 6, res: 8, spd: 10, mv: 4, jp: 2, ev: 10, w: 'claw', watk: 6, abil: ['m_punch'], weak: [], loot: ['grimfang'], col: '#6f8a3a', shape: 'goblin', g: { hp: 7, atk: 1.8, def: 1.2, mag: .5, res: .8, spd: .3 } },
  wolfhound: { name: 'Wolfhound', hp: 66, mp: 0, atk: 20, def: 9, mag: 6, res: 8, spd: 13, mv: 5, jp: 2, ev: 20, w: 'claw', watk: 6, abil: ['m_bite', 'm_howl'], weak: ['fire'], loot: ['wolfpelt'], col: '#7a7468', shape: 'wolf', g: { hp: 6.5, atk: 1.7, def: 1, mag: .5, res: .8, spd: .5 } },
  ooze: { name: 'Ooze', hp: 80, mp: 30, atk: 14, def: 18, mag: 18, res: 12, spd: 8, mv: 3, jp: 1, ev: 5, w: 'claw', watk: 4, abil: ['m_sludge'], weak: ['fire'], resist: ['water', 'ice'], physHalf: true, loot: ['oozegel'], col: '#5aa0a0', shape: 'ooze', g: { hp: 7, atk: 1, def: 1.5, mag: 1.8, res: 1.2, spd: .3 } },
  sandmaw: { name: 'Sandmaw', hp: 95, mp: 0, atk: 24, def: 16, mag: 8, res: 9, spd: 8, mv: 3, jp: 1, ev: 5, w: 'claw', watk: 8, abil: ['m_crush', 'm_pit'], weak: ['ice', 'water'], loot: ['maw'], col: '#b08a50', shape: 'bug', g: { hp: 9, atk: 2, def: 1.6, mag: .5, res: .8, spd: .3 } },
  mirehag: { name: 'Mire Hag', hp: 150, mp: 80, atk: 16, def: 12, mag: 26, res: 18, spd: 11, mv: 4, jp: 2, ev: 12, w: 'staff', watk: 6, abil: ['m_mire', 'm_hex', 'm_leech'], weak: ['holy', 'fire'], loot: ['hagcharm', 'miremoss'], col: '#4a5a3a', shape: 'hag', boss: true, g: { hp: 12, atk: 1, def: 1.2, mag: 2.6, res: 1.8, spd: .4 } },
};

// Laws. Each day has a banned action (breaking it earns a card) and a favored action (+1 JP).
const LAWS = {
  noitem: { name: 'Items', k: 'cat', v: 'item' }, nomagic: { name: 'Magic', k: 'cat', v: 'mag' },
  noheal: { name: 'Healing', k: 'fx', v: 'heal' }, nostatus: { name: 'Status effects', k: 'status', v: 1 },
  noranged: { name: 'Ranged attacks', k: 'ranged', v: 1 },
  nofire: { name: 'Fire', k: 'el', v: 'fire' }, noice: { name: 'Ice', k: 'el', v: 'ice' }, nobolt: { name: 'Lightning', k: 'el', v: 'bolt' },
  nowater: { name: 'Water', k: 'el', v: 'water' }, nowind: { name: 'Wind', k: 'el', v: 'wind' }, nodark: { name: 'Dark', k: 'el', v: 'dark' },
  nosword: { name: 'Swords', k: 'w', v: 'sword' }, noknife: { name: 'Knives', k: 'w', v: 'knife' }, nobow: { name: 'Bows', k: 'w', v: 'bow' },
  nospear: { name: 'Spears', k: 'w', v: 'spear' }, nogs: { name: 'Greatswords', k: 'w', v: 'greatsword' },
  nofight: { name: 'Fight command', k: 'fight', v: 1 }, nosteal: { name: 'Stealing', k: 'fx', v: 'steal' },
  nobuff: { name: 'Buffs', k: 'fx', v: 'buff' },
};

// Terrain. pass: can stand on. Colors: [top, left side, right side]
const TERRAIN = {
  g: { name: 'Grass', pass: 1, c: ['#6f9a4c', '#58703a', '#46592e'] },
  d: { name: 'Dirt', pass: 1, c: ['#a08058', '#7d6244', '#664f37'] },
  s: { name: 'Stone', pass: 1, c: ['#9a968a', '#77746a', '#625f57'] },
  c: { name: 'Cinder', pass: 1, c: ['#6a5c56', '#524641', '#433935'] },
  r: { name: 'Crag', pass: 1, c: ['#857a6c', '#675d52', '#544c43'] },
  a: { name: 'Sand', pass: 1, c: ['#d8c48c', '#b09e6e', '#958559'] },
  m: { name: 'Swamp', pass: 1, c: ['#566a48', '#43543a', '#36442f'] },
  w: { name: 'Shallows', pass: 1, c: ['#4f8fb8', '#3b6f90', '#2f5a75'], water: 1 },
  W: { name: 'Deep water', pass: 0, c: ['#2f6a9a', '#255479', '#1d4462'], water: 1 },
  b: { name: 'Bridge', pass: 1, c: ['#8a6a44', '#6c5235', '#57422b'] },
  t: { name: 'Tree', pass: 0, c: ['#5a7a40', '#475f33', '#3a4e2a'], tree: 1 },
  l: { name: 'Lava', pass: 0, c: ['#e0602a', '#a8441e', '#8a3618'], lava: 1 },
};

// Maps: rows of "terrain+height" tokens. deploy: player start tiles.
const MAPS = {
  briar: {
    name: 'Briar Ford', rows: [
      'g2 g2 g2 g1 g1 W0 W0 g1 g1 g2 g3 g3',
      'g2 g3 g2 g1 g1 W0 W0 g1 g1 g2 g3 g3',
      'g2 g2 g1 g1 d1 b1 b1 d1 g1 g1 g2 g2',
      'g1 g1 g1 d1 d1 W0 W0 g1 g1 g1 g2 g2',
      'g1 t2 g1 g1 g1 W0 W0 g1 t2 g1 g1 g1',
      'g1 g1 g1 g1 g1 W0 W0 g1 a1 g1 g1 g1',
      'g1 g2 g2 g1 a1 w0 w0 a1 g1 g1 t2 g1',
      'g1 g2 g3 g2 g1 w0 w0 g1 g1 g1 g1 g1',
      'g1 g2 g2 g1 g1 W0 W0 g1 g1 g2 g2 g1',
      'g1 g1 g1 g1 g1 W0 W0 g1 g1 g2 g2 g2'],
    deploy: [[1, 9], [2, 9], [3, 8], [1, 8], [3, 9], [0, 7]],
  },
  quarry: {
    name: 'Cinder Quarry', rows: [
      's6 s6 s6 s5 s4 s4 r7 r7 s6 s6 s6',
      's6 s6 s5 s4 s4 s4 r7 s6 s6 s6 s6',
      's5 s5 s4 c3 c3 s4 s5 s6 s6 r7 r7',
      'r5 s4 c3 c3 c3 c3 s4 s5 s5 s6 r7',
      's4 s3 c2 c2 c2 c3 c3 s4 s4 s5 s5',
      's3 s2 c2 c1 c1 c2 c2 c3 s4 s4 s4',
      's2 s2 c1 c1 l0 l0 c1 c2 c3 s3 s3',
      's2 s1 c1 c1 l0 l0 c1 c1 c2 s3 r4',
      's1 s1 d1 c1 c1 c1 c1 d1 d2 s2 s3',
      'd1 d1 d1 d1 d1 d1 d1 d1 d1 s2 s2',
      'd1 d1 d1 d1 d1 d1 d1 d1 d1 d1 s2'],
    deploy: [[1, 10], [2, 10], [3, 10], [2, 9], [4, 10], [1, 9]],
  },
  mirewood: {
    name: 'Mirewood Hollow', rows: [
      'g2 g2 t3 g2 g2 m1 m1 g2 g3 g3 t3 g3',
      'g2 g3 g3 g2 m1 m0 m0 m1 g2 g3 g3 g3',
      't3 g2 g2 m1 m0 W0 W0 m0 m1 g2 g2 t3',
      'g2 g2 m1 m0 W0 W0 W0 W0 m0 m1 g2 g2',
      'g1 m1 m0 m0 W0 W0 W0 m0 m0 d1 d1 g2',
      'g1 m1 m0 d1 d1 m0 m0 d1 d1 d1 t2 g2',
      't2 g1 d1 d1 g2 g2 t3 g2 d1 m0 m1 g1',
      'g1 g1 d1 g2 g3 g3 g2 g1 d1 m0 m0 m1',
      'g1 d1 d1 g2 t3 g2 g1 g1 d1 d1 m0 m1',
      'd1 d1 g1 g1 g2 g1 g1 t2 g1 d1 d1 m1',
      'd1 d1 d1 g1 g1 g1 g1 g1 g1 g1 d1 g1',
      'd1 d1 d1 d1 g1 g1 t2 g1 g1 g1 g1 g1'],
    deploy: [[1, 11], [2, 11], [3, 11], [1, 10], [2, 10], [0, 9]],
  },
};

// Story missions (the first three locations). Enemies: [kind, level, x, y, extra]
// kind is a monster id, or 'race:job' for a clan unit.
const MISSIONS = [
  {
    id: 'm1', name: 'Toll at the Ford', loc: 'briar', map: 'briar', deploy: 4, law: { ban: 'noitem', fav: 'nofight' },
    brief: 'Grimkin have taken the old bridge at Briar Ford and are robbing travelers. Drive them off.',
    enemies: [['grimkin', 1, 8, 1], ['grimkin', 1, 9, 2], ['grimkin', 2, 10, 0], ['wolfhound', 1, 8, 3]],
    reward: { gil: 300, ap: 30, loot: { wolfpelt: 1, grimfang: 1 }, items: { potion: 2 } },
  },
  {
    id: 'm2', name: 'Ashfang Raiders', loc: 'quarry', map: 'quarry', deploy: 5, law: { ban: 'nofire', fav: 'noice' },
    brief: 'A rival clan, the Ashfang, has seized the quarry road. Their leader Korr will not leave without a fight.',
    enemies: [['saurian:warrior', 3, 5, 1, { name: 'Korr', leader: 1, eq: ['bastard', 'bronzeplate', 'ironhelm'] }], ['human:archer', 2, 8, 1, { eq: ['huntbow', 'leathervest'] }], ['human:arcanist', 2, 7, 0, { eq: ['emberrod', 'linenrobe'] }], ['human:rogue', 3, 3, 2, { eq: ['kris', 'leathervest'] }], ['saurian:cleric', 2, 9, 0, { eq: ['pilgrim', 'linenrobe'] }]],
    reward: { gil: 600, ap: 40, loot: { emberstone: 1, quarryore: 2 }, items: { hipotion: 1 } },
  },
  {
    id: 'm3', name: 'The Hag of the Hollow', loc: 'mirewood', map: 'mirewood', deploy: 6, law: { ban: 'nowater', fav: 'nofire' },
    brief: 'Villagers vanish in Mirewood Hollow. Something old lives in the bog. Find it and end it.',
    enemies: [['mirehag', 5, 6, 0], ['ooze', 4, 4, 1], ['ooze', 4, 8, 1], ['sandmaw', 4, 9, 4], ['wolfhound', 4, 2, 3], ['grimkin', 4, 10, 2]],
    reward: { gil: 900, ap: 50, loot: { hagcharm: 1, miremoss: 2, silkthread: 1 }, items: { phoenix: 1 } },
  },
];

// World map locations (x, y in a 100x140 box)
const LOCS = {
  town: { name: 'Harrowgate', x: 30, y: 112, town: 1, desc: 'Your home town. Shop, bazaar and pub.' },
  briar: { name: 'Briar Ford', x: 62, y: 92, map: 'briar' },
  quarry: { name: 'Cinder Quarry', x: 28, y: 62, map: 'quarry' },
  mirewood: { name: 'Mirewood Hollow', x: 70, y: 30, map: 'mirewood' },
};
const ROUTES = [['town', 'briar'], ['briar', 'quarry'], ['quarry', 'mirewood'], ['town', 'quarry']];

// Errands: send one unit away for a few battles.
const ERRANDS = [
  { id: 'e1', name: 'Escort a Merchant', job: null, minLv: 1, len: 2, gil: 250, loot: 'silkthread' },
  { id: 'e2', name: 'Hunt Ford Wolves', job: 'archer', minLv: 2, len: 2, gil: 200, loot: 'wolfpelt' },
  { id: 'e3', name: 'Survey the Quarry', job: null, minLv: 3, len: 3, gil: 350, loot: 'quarryore' },
  { id: 'e4', name: 'Tend the Sick', job: 'mender', minLv: 2, len: 2, gil: 300, loot: null },
  { id: 'e5', name: 'Guard the Granary', job: 'warrior', minLv: 3, len: 2, gil: 300, loot: 'grimfang' },
  { id: 'e6', name: 'Copy Old Scrolls', job: 'sage', minLv: 2, len: 3, gil: 400, loot: 'emberstone' },
  { id: 'e7', name: 'Catch a Thief', job: 'rogue', minLv: 3, len: 2, gil: 350, loot: 'silkthread' },
  { id: 'e8', name: 'Skim the Bog', job: null, minLv: 5, len: 3, gil: 450, loot: 'oozegel' },
  { id: 'e9', name: 'Herd Strays', job: 'animist', minLv: 2, len: 2, gil: 260, loot: 'wolfpelt' },
  { id: 'e10', name: 'Dig for Embers', job: 'saurian', minLv: 4, len: 3, gil: 400, loot: 'emberstone' },
];

const NAMES = {
  human: ['Rook', 'Tamsin', 'Edda', 'Corin', 'Wren', 'Hale', 'Ivo', 'Maren', 'Sorrel', 'Brand', 'Isolde', 'Fenn'],
  saurian: ['Bram', 'Kesh', 'Drago', 'Varn', 'Ossa', 'Thrak', 'Gorl', 'Zhet'],
  sylph: ['Liss', 'Aerin', 'Siv', 'Neve', 'Ylva', 'Rhea', 'Tiri', 'Elowen'],
  mossling: ['Pip', 'Tuft', 'Bobbin', 'Moss', 'Nib', 'Pom', 'Dottle', 'Burr'],
  nuwa: ['Oro', 'Quell', 'Hemmet', 'Ulm', 'Sabre', 'Ixo', 'Pell', 'Nauro'],
};
const BASE_JOBS = { human: ['squire', 'archer', 'mender', 'arcanist', 'rogue'], saurian: ['warrior', 'cleric'], sylph: ['fencer', 'archer', 'mender'], mossling: ['animist', 'gunner', 'rogue'], nuwa: ['sage', 'mender', 'alchemist'] };
// Default gear for a job (used for recruits and enemy clans)
const STARTER = { squire: ['ironsword', 'leathervest', 'buckler'], archer: ['huntbow', 'leathervest'], mender: ['oakstaff', 'linenrobe'], arcanist: ['emberrod', 'linenrobe'], rogue: ['dagger', 'leathervest'], warrior: ['cleaver', 'bronzeplate'], cleric: ['pilgrim', 'linenrobe'], fencer: ['fleuret', 'leathervest'], animist: ['reedpipe', 'leathervest'], gunner: ['flintlock', 'leathervest'], sage: ['tiderod', 'linenrobe'], alchemist: ['mortar', 'linenrobe'], knight: ['knightblade', 'bronzeplate', 'ironhelm'], spellblade: ['flamesaber', 'leathervest'], shadow: ['kris', 'leathervest'], wyrmlancer: ['partisan', 'bronzeplate'], brawler: ['cestus', 'leathervest'], summoner: ['emberstaff', 'linenrobe'], deadeye: ['longbow', 'leathervest'], tinker: ['jesterknife', 'leathervest'], mossknight: ['mossbrand', 'bronzeplate'], chronomancer: ['hourstaff', 'linenrobe'], illusionist: ['prismrod', 'linenrobe'] };

if (typeof module !== 'undefined') module.exports = { RACES, JOBS, AB, STATUS, ELEMENTS, WTYPES, ITEMS, CONS, LOOT, RECIPES, MONSTERS, LAWS, TERRAIN, MAPS, MISSIONS, LOCS, ROUTES, ERRANDS, NAMES, BASE_JOBS, STARTER };
