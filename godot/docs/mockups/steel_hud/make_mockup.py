#!/usr/bin/env python3
"""The steel battle HUD mockup (Nov 2026): every part of the battle screen restyled to match the new command menu (SteelMenu).

    python3 godot/docs/mockups/steel_hud/make_mockup.py      # writes index.html; render_mockup.js saves frame_1..3.png

Frame 1 the battle HUD, frame 2 the Abilities submenu with a target and a damage forecast, frame 3 the style sheet. A DESIGN MOCKUP in HTML over a real
render of the Last Benediction battle (board_backdrop.png, from tests/last_benediction_unselected_shot.tscn -- nohud keep): nothing here is in the game
except the command menu. The real fonts (Cinzel for headings, Inter for gameplay text, nothing under 16 px), icons and portraits are the game's own.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
UNITS = json.load(open(os.path.join(HERE, "board_units.json")))
CH = "../../../assets/characters/%s/portraits/portrait_01.png"
ICON = "../../../assets/ui/icon_%s.png"

CSS = """
@font-face{font-family:Inter;src:url(../../../assets/fonts/Inter-Regular.ttf);font-weight:400}
@font-face{font-family:Inter;src:url(../../../assets/fonts/Inter-Medium.ttf);font-weight:500}
@font-face{font-family:Inter;src:url(../../../assets/fonts/Inter-SemiBold.ttf);font-weight:600}
@font-face{font-family:Inter;src:url(../../../assets/fonts/Inter-Bold.ttf);font-weight:700}
@font-face{font-family:Cinzel;src:url(../../../assets/fonts/Cinzel-Bold.ttf);font-weight:700}
:root{--ice:#8fd4ff;--ink:#e6eef8;--mute:#8b9aad;--hp:#58d68d;--hpe:#e0604f;--sp:#5aa9ff;--xp:#d4b06a;--c:12px}
*{box-sizing:border-box}
body{margin:0;background:#07090d;font-family:Inter,sans-serif;color:var(--ink);font-size:18px}
.frame{position:relative;width:1920px;height:1080px;overflow:hidden;margin:0 0 24px}
.frame>img.bg{position:absolute;left:0;top:0;width:1920px;height:1080px}
.abs{position:absolute}
.cin{font-family:Cinzel,serif;font-weight:700;letter-spacing:.06em}
.sh{position:absolute;filter:drop-shadow(0 6px 10px rgba(0,0,0,.6))}
.glow{position:absolute;filter:drop-shadow(0 0 7px rgba(110,190,255,.65)) drop-shadow(0 4px 8px rgba(0,0,0,.5))}
.pl{position:relative;width:100%;height:100%;background:linear-gradient(180deg,#60758e,#2a3646);
 clip-path:polygon(var(--c) 0,calc(100% - var(--c)) 0,100% var(--c),100% calc(100% - var(--c)),calc(100% - var(--c)) 100%,var(--c) 100%,0 calc(100% - var(--c)),0 var(--c))}
.pl>.in{position:absolute;inset:1px;background:linear-gradient(180deg,#19222d 0%,#0d131a 100%);
 clip-path:polygon(calc(var(--c) - 1px) 0,calc(100% - var(--c) + 1px) 0,100% calc(var(--c) - 1px),100% calc(100% - var(--c) + 1px),calc(100% - var(--c) + 1px) 100%,calc(var(--c) - 1px) 100%,0 calc(100% - var(--c) + 1px),0 calc(var(--c) - 1px));
 box-shadow:inset 0 1px 0 rgba(190,215,255,.09)}
.pl.lit{background:linear-gradient(180deg,#b9e6ff,#5aa9e0)}
.pl.lit>.in{background:linear-gradient(180deg,#0b1d3a 0%,#2d4a6f 100%)}
.pl.off>.in{background:linear-gradient(180deg,#2a313a,#2e353e)}
.hx{position:relative;width:100%;height:100%;background:linear-gradient(180deg,#566a82,#222c39);--t:18px;
 clip-path:polygon(0 50%,var(--t) 0,calc(100% - var(--t)) 0,100% 50%,calc(100% - var(--t)) 100%,var(--t) 100%)}
.hx>.in{position:absolute;inset:1px;background:linear-gradient(180deg,#151c26,#1f2834);
 clip-path:polygon(0 50%,calc(var(--t) - .5px) 0,calc(100% - var(--t) + .5px) 0,100% 50%,calc(100% - var(--t) + .5px) 100%,calc(var(--t) - .5px) 100%)}
.hx.lit{background:linear-gradient(180deg,#c8ecff,#6fb7ec)}
.hx.lit>.in{background:
 repeating-linear-gradient(90deg,rgba(255,255,255,.035) 0 1px,transparent 1px 3px),
 linear-gradient(180deg,#0b1d3a 0%,#2d4a6f 100%)}
.hx.lit>.in::after{content:"";position:absolute;left:12%;right:12%;bottom:0;height:2px;background:linear-gradient(90deg,transparent,rgba(210,240,255,.85) 45%,transparent)}
.hx.off>.in{background:linear-gradient(180deg,#262d35,#2c323b)}
.lbl{position:absolute;display:flex;align-items:center;gap:12px;font-weight:600;font-size:20px;color:#a9b6c6}
.lit .lbl,.lbl.lit{color:#f4f9ff}
.off .lbl{color:#69737f}
.ico{width:22px;height:22px;opacity:.9}
.chev{position:absolute;right:26px;top:50%;width:9px;height:9px;border-top:2px solid currentColor;border-right:2px solid currentColor;transform:translateY(-50%) rotate(45deg)}
.bar{position:relative;height:10px;background:#05080c;border:1px solid #2f3e50;clip-path:polygon(4px 0,100% 0,calc(100% - 4px) 100%,0 100%)}
.bar>i{position:absolute;left:0;top:0;bottom:0;display:block}
.hp>i{background:linear-gradient(180deg,#8be8b3,#35a56b)}
.hpe>i{background:linear-gradient(180deg,#f08a7a,#b8392b)}
.spb>i{background:linear-gradient(180deg,#8cc6ff,#3578c4)}
.xpb>i{background:linear-gradient(180deg,#ecd08e,#a8803a)}
.mom>i{background:linear-gradient(180deg,#cfeeff,#4f9fdc)}
.bar.abs{position:absolute}
.bar.thin{height:8px}
.bar .seg{position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0 31px,rgba(0,0,0,.55) 31px 33px)}
.cap{font-size:16px;color:var(--mute)}
.rule{position:absolute;height:1px;background:linear-gradient(90deg,transparent,#8fb4d4 20%,#8fb4d4 80%,transparent);opacity:.4}
.dia{position:absolute;width:9px;height:9px;background:#8fb4d4;opacity:.6;transform:rotate(45deg)}
.chip{position:absolute;display:flex;align-items:center;justify-content:center;font-weight:600;font-size:16px;color:#e8f4ff;white-space:nowrap}
.tabs .tab{position:absolute;height:32px}
.port{position:absolute;overflow:hidden;background:#0a0f15;clip-path:polygon(8px 0,100% 0,100% calc(100% - 8px),calc(100% - 8px) 100%,0 100%,0 8px)}
.port img{width:100%;height:100%;object-fit:cover;object-position:50% 12%;display:block}
.marker{position:absolute;width:0;height:0;border-left:9px solid transparent;border-right:9px solid transparent;border-top:12px solid var(--ice);filter:drop-shadow(0 0 5px rgba(120,200,255,.9))}
"""


def plate(x, y, w, h, inner="", c=12, cls="", shadow=True):
    wrap = "sh" if shadow else "abs"
    if "lit" in cls:
        wrap = "glow"
    return (f'<div class="{wrap}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><div class="pl {cls}" style="--c:{c}px">'
            f'<div class="in"></div>{inner}</div></div>')


def hexbar(x, y, w, h, inner="", cls=""):
    wrap = "glow" if "lit" in cls else "abs"
    return (f'<div class="{wrap}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><div class="hx {cls}" style="--t:{h // 2}px">'
            f'<div class="in"></div>{inner}</div></div>')


def cmd(x, y, name, icon, cls="", chevron=False, w=500, h=36):
    lbl = (f'<div class="lbl" style="left:34px;top:0;height:{h}px"><img class="ico" src="{ICON % icon}" '
           f'style="filter:{"brightness(1.4)" if "lit" in cls else "brightness(.85)"}">{name}</div>')
    if chevron:
        lbl += f'<div class="chev" style="color:{"#69737f" if "off" in cls else "#cfe6ff" if "lit" in cls else "#8795a6"}"></div>'
    return hexbar(x, y, w, h, lbl, cls)


def bar(x, y, w, pct, kind="hp", cls=""):
    return f'<div class="abs bar {kind} {cls}" style="left:{x}px;top:{y}px;width:{w}px"><i style="width:{pct}%"></i></div>'


def ornament(x, y, w):
    cx = x + w // 2
    return (f'<div class="rule" style="left:{x + 26}px;top:{y}px;width:{w // 2 - 38}px"></div><div class="rule" style="left:{cx + 12}px;top:{y}px;width:{w // 2 - 38}px"></div>'
            f'<div class="dia" style="left:{cx - 4}px;top:{y - 4}px"></div>')


def portrait(x, y, w, h, who, pos="50% 12%"):
    return f'<div class="port" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><img src="{CH % who}" style="object-position:{pos}"></div>'


def chip(x, y, w, text, cls="", h=30):
    return hexbar(x, y, w, h, f'<div class="chip" style="inset:0">{text}</div>', cls)


def caption_tab(x, y, w, text):
    inner = (f'<div class="abs cin" style="inset:0;display:flex;align-items:center;justify-content:center;font-size:19px;color:#cfe6ff;letter-spacing:.14em">{text}</div>'
             '')
    return hexbar(x, y, w, 34, inner)


def unit_card(x, y, caption, who, name, lv, role, hp, hpmax, sp=None, xp=None, kind="hp", chipt=None, pos="50% 12%"):
    inner = portrait(18, 20, 100, 118, who, pos)
    inner += f'<div class="abs cin" style="left:136px;top:18px;font-size:{28 if len(name) > 7 else 32}px;color:#f0f6ff">{name}</div>'
    inner += f'<div class="abs" style="right:24px;top:24px;font-size:22px;font-weight:600;color:#cdd8e6">Lv {lv}</div>'
    inner += '<div class="rule" style="left:136px;top:64px;width:270px"></div><div class="dia" style="left:266px;top:60px"></div>'
    inner += f'<div class="abs" style="left:136px;top:74px;font-size:20px;color:#9eacbd">{role}</div>'
    rows = [("HP", f"{hp} / {hpmax}", 100.0 * hp / hpmax, kind, "#7fe0a8" if kind == "hp" else "#f09a8c")]
    if sp is not None:
        rows.append(("SP", f"{sp[0]} / {sp[1]}", 100.0 * sp[0] / sp[1], "spb", "#8cc6ff"))
    if xp is not None:
        rows.append(("XP", f"{xp[0]} / {xp[1]}", 100.0 * xp[0] / xp[1], "xpb", "#e0c486"))
    yy = 104
    for lab, val, pct, k, colr in rows:
        inner += f'<div class="abs" style="left:136px;top:{yy}px;font-size:18px;font-weight:700;color:{colr}">{lab}</div>'
        inner += f'<div class="abs" style="right:24px;top:{yy}px;font-size:18px;font-weight:600;color:#e6eef8">{val}</div>'
        inner += bar(136, yy + 27, 268, pct, k)
        yy += 48 if False else 46
    if chipt:
        inner += chip(322, 70, 92, chipt, "", 28)
    return caption_tab(x + 147, y - 24, 134, caption) + plate(x, y, 428, 250, inner, 14)


def world_overlays(skip_label_cover=False):
    out = ""
    for key, u in UNITS.items():
        hx, hy = u["head"]
        pct = 100.0 * u["hp"] / u["max"]
        out += bar(hx - 28, hy - 70, 56, pct, "hp" if u["team"] == 0 else "hpe", "thin")
        if key.startswith("Alaric"):
            out += f'<div class="marker" style="left:{hx - 9}px;top:{hy - 100}px"></div>'
    return out


def stone_chips():
    out = ""
    for text, x, y in [("Brace", 784, 110), ("Poison Spit", 960, 110), ("Rally Cry", 1268, 229), ("Ember Flick", 1170, 509), ("Crescent Strike", 1030, 563)]:
        w = 46 + 9 * len(text)
        out += chip(x - w // 2, y - 15, w, text, "", 30)
    return out


def top_hud(active=0):
    out = ""
    # turn banner
    banner = ('<div class="sh" style="left:0;top:18px;width:436px;height:62px"><div class="hx" style="--t:0;clip-path:polygon(0 0,calc(100% - 30px) 0,100% 50%,calc(100% - 30px) 100%,0 100%)">'
              '<div class="in" style="clip-path:polygon(0 0,calc(100% - 30.5px) 0,100% 50%,calc(100% - 30.5px) 100%,0 100%)"></div>'
              '<div class="abs cin" style="left:40px;top:0;height:62px;display:flex;align-items:center;font-size:40px;color:#f0f6ff">TURN 1</div></div></div>')
    out += banner
    obj = ('<div class="abs cin" style="left:28px;top:12px;font-size:22px;color:#cfe6ff;letter-spacing:.12em">OBJECTIVES</div>'
           '<div class="abs" style="left:28px;top:44px;font-size:20px;font-weight:500;color:#dbe6f2"><span style="color:#8fd4ff">◆</span>&nbsp; Defeat every enemy</div>')
    out += plate(0, 96, 440, 82, obj, 12)
    # turn order
    cards = [("alaric_v2", "Alaric", 1.0, 0), ("hooded_cutthroat", "Watch", 1.0, 1), ("forest_wolf", "Rot-H…", 1.0, 1), ("hooded_cutthroat", "Watch", 1.0, 1),
             ("riverband_brute", "Town", 1.0, 1), ("alaric_v2", "Alaric", .76, 0), ("hooded_cutthroat", "Watch", 1.0, 1)]
    inner = ""
    for i, (who, nm, hp, team) in enumerate(cards):
        cx = 52 + i * 132
        lit = "lit" if i == active else ""
        body = portrait(8, 8, 46, 46, who) + f'<div class="abs" style="left:62px;top:6px;font-size:17px;font-weight:600;color:{"#f4f9ff" if lit else "#b6c3d3"}">{nm}</div>'
        body += bar(62, 38, 54, hp * 100, "hp" if team == 0 else "hpe", "thin")
        inner += plate(cx, 10, 128, 62, body, 9, lit, shadow=False)
    inner += hexbar(10, 22, 30, 38, '<div class="abs" style="inset:0;display:flex;align-items:center;justify-content:center;font-size:24px;color:#9fc3e0">‹</div>')
    inner += hexbar(970, 22, 30, 38, '<div class="abs" style="inset:0;display:flex;align-items:center;justify-content:center;font-size:24px;color:#9fc3e0">›</div>')
    out += plate(455, 18, 1010, 82, inner, 14)
    # momentum
    mom = ('<div class="abs cin" style="left:24px;top:12px;font-size:22px;color:#cfe6ff;letter-spacing:.12em">MOMENTUM</div>'
           '<div class="abs bar mom" style="left:24px;top:46px;width:322px;height:14px"><i style="width:18%"></i><div class="seg"></div></div>')
    mom += hexbar(24, 70, 160, 36, '<div class="lbl" style="inset:0;justify-content:center;color:#69737f">Surge [F]</div>', "off")
    mom += hexbar(196, 70, 150, 36, '<div class="lbl" style="inset:0;justify-content:center">Speed 1×</div>')
    mom += '<div class="abs cap" style="left:24px;top:114px;width:330px">Hits, criticals, pincers and knockouts fill it.</div>'
    out += plate(1525, 18, 370, 150, mom, 12)
    return out


def command_menu(x=710, y=812, lit=0, disabled=(1, 2)):
    names = [("Attack", "attack", False), ("Abilities", "abilities", True), ("Items", "items", True), ("Summon", "summon", True), ("Wait", "wait", False), ("Move", "move", False)]
    out = ornament(x, y + 6, 500) + ornament(x, y + 14 + 6 * 39 + 3, 500)
    for i, (n, ic, ch) in enumerate(names):
        cls = "lit" if i == lit else ("off" if i in disabled else "")
        out += cmd(x, y + 14 + i * 39, n, ic, cls, ch)
    return out


def frame1():
    h = '<div class="frame"><img class="bg" src="board_backdrop.png">'
    h += world_overlays() + stone_chips() + top_hud(0) + command_menu()
    h += unit_card(1467, 805, "ACTING", "alaric_v2", "ALARIC", 1, "King · Rook Impact", 21, 28, (9, 9), (0, 100), chipt="Marked 1")
    h += '</div>'
    return h


def skill_row(x, y, name, cost, lv, pct, cls="", w=520, h=54):
    inner = f'<div class="lbl" style="left:34px;top:6px;height:24px;font-size:20px">{name}</div>'
    inner += f'<div class="abs" style="right:34px;top:6px;height:24px;font-size:18px;font-weight:600;color:{"#69737f" if "off" in cls else "#9fb2c8"}">{cost}</div>'
    inner += bar(34, 34, w - 68, pct, "xpb" if "lit" not in cls else "mom", "thin")
    return hexbar(x, y, w, h, inner, cls)


def frame2():
    h = '<div class="frame"><img class="bg" src="board_backdrop.png">'
    h += world_overlays() + stone_chips() + top_hud(0)
    # forecast + target at the left
    fc = ('<div class="abs cin" style="left:24px;top:14px;font-size:22px;color:#cfe6ff;letter-spacing:.12em">FORECAST</div>'
          '<div class="abs" style="right:24px;top:14px;font-size:20px;font-weight:600;color:#8fd4ff">Crescent Strike</div>'
          '<div class="rule" style="left:24px;top:52px;width:380px"></div>')
    rows = [("Hit chance", "87%", "#e6eef8"), ("Damage", "14", "#f0c27a"), ("Critical", "12%", "#e6eef8")]
    for i, (a, b, c) in enumerate(rows):
        fc += f'<div class="abs" style="left:24px;top:{64 + i * 32}px;font-size:19px;color:#9eacbd">{a}</div><div class="abs" style="right:24px;top:{64 + i * 32}px;font-size:20px;font-weight:700;color:{c}">{b}</div>'
    fc += '<div class="abs" style="left:24px;top:164px;font-size:18px;color:#9eacbd">Target HP</div><div class="abs" style="right:24px;top:164px;font-size:18px;font-weight:600">39 → 25</div>'
    fc += ('<div class="abs bar hpe" style="left:24px;top:192px;width:380px;height:14px"><i style="width:100%"></i>'
           '<i style="left:64%;width:36%;background:repeating-linear-gradient(135deg,#fff 0 3px,#8f2a20 3px 6px);opacity:.55"></i></div>')
    fc += chip(24, 214, 118, "Back attack", "", 28) if False else ''
    h += plate(24, 520, 428, 232, fc, 14)
    h += unit_card(24, 805, "TARGET", "forest_wolf", "ROT-HOUND", 3, "Beast · Bite", 39, 39, None, None, "hpe", pos="50% 25%")
    # abilities submenu in the bars' place
    x0, y0 = 470, 520
    sub = ('<div class="abs cin" style="left:32px;top:20px;font-size:30px;color:#e9f4ff">ABILITIES</div>'
           '<div class="abs cap" style="right:32px;top:30px">SP 9 / 9&nbsp; ·&nbsp; 6 skills</div><div class="rule" style="left:32px;top:66px;width:916px"></div>')
    for i, (t, n) in enumerate([("All", 6), ("★ Favorites", 2), ("Physical", 3), ("Fire", 1), ("Holy", 2)]):
        wt = 22 + 11 * len(t) + 44
        sub += hexbar(32 + sum(22 + 11 * len(tt) + 44 + 8 for tt, _ in [("All", 6), ("★ Favorites", 2), ("Physical", 3), ("Fire", 1), ("Holy", 2)][:i]), 78, wt, 32,
                      f'<div class="chip" style="inset:0">{t}&nbsp;<span style="color:#8fb4d4">{n}</span></div>', "lit" if i == 0 else "")
    skills = [("Crescent Strike", "3 SP", "Lv 2", 47, "lit"), ("Hamstring Cut", "2 SP", "Lv 1", 20, ""), ("Brace", "2 SP", "Lv 3", 90, ""), ("Fleet Foot", "4 SP", "Lv 0", 6, ""), ("Frost Prick", "12 SP", "Lv 1", 33, "off")]
    for i, (n, c, l, p, cls) in enumerate(skills):
        sub += skill_row(32, 124 + i * 58, n, c, l, p, cls)
    # detail pane
    det = ('<div class="abs cin" style="left:24px;top:18px;font-size:24px;color:#f0f6ff">Crescent Strike</div>'
           + hexbar(278, 50, 90, 30, '<div class="chip" style="inset:0;font-size:16px">Rank E</div>')
           + '<div class="abs cap" style="left:24px;top:54px">Physical · Slash</div><div class="rule" style="left:24px;top:90px;width:332px"></div>'
           '<div class="abs" style="left:24px;top:102px;width:336px;font-size:18px;line-height:1.45;color:#c4d0de">A wide sweeping cut that strikes the target and the tiles beside it.</div>'
           '<div class="abs" style="left:24px;top:182px;font-size:18px;color:#9eacbd">Cost</div><div class="abs" style="left:100px;top:182px;font-size:18px;font-weight:700">3 SP</div>'
           '<div class="abs" style="left:190px;top:182px;font-size:18px;color:#9eacbd">Power</div><div class="abs" style="left:262px;top:182px;font-size:18px;font-weight:700">120%</div>'
           '<div class="abs" style="left:24px;top:222px;font-size:18px;font-weight:700;color:#e0c486">Lv 2</div><div class="abs" style="right:24px;top:222px;font-size:18px;font-weight:600">14 / 30</div>'
           + bar(24, 250, 332, 47, "xpb")
           + chip(24, 276, 124, "Learning", "", 30))
    sub += plate(566, 118, 382, 316, det, 10)
    sub += hexbar(410, 470, 160, 40, '<div class="lbl" style="inset:0;justify-content:center">Back</div>')
    h += plate(x0, y0, 980, 530, sub, 16)
    h += unit_card(1467, 805, "ACTING", "alaric_v2", "ALARIC", 1, "King · Rook Impact", 21, 28, (9, 9), (0, 100), chipt="Marked 1")
    h += '</div>'
    return h


def frame3():
    h = '<div class="frame" style="background:linear-gradient(180deg,#0b1017,#05080c)">'
    h += '<div class="abs cin" style="left:60px;top:40px;font-size:44px;color:#f0f6ff">STEEL HUD · STYLE SHEET</div>'
    h += '<div class="abs" style="left:60px;top:100px;font-size:20px;color:#9eacbd">One material for every part of the battle screen: dark engraved steel, one icy-blue light, Cinzel for headings, Inter for the rest.</div>'
    # swatches
    sw = [("Steel 0", "#0d131a"), ("Steel 1", "#19222d"), ("Steel 2", "#2a3646"), ("Edge", "#566a82"), ("Ice", "#8fd4ff"), ("Ice lit", "#c8ecff"), ("Navy", "#0b1d3a"), ("Slate", "#2d4a6f"),
          ("HP", "#58d68d"), ("Foe HP", "#e0604f"), ("SP", "#5aa9ff"), ("XP / reward", "#d4b06a")]
    h += '<div class="abs cap" style="left:60px;top:160px;font-size:18px;font-weight:600;color:#cfe6ff">COLOUR</div>'
    for i, (n, c) in enumerate(sw):
        h += f'<div class="abs" style="left:{60 + (i % 4) * 128}px;top:{194 + (i // 4) * 92}px;width:116px;height:48px;background:{c};border:1px solid #3a4a5e"></div><div class="abs cap" style="left:{60 + (i % 4) * 128}px;top:{246 + (i // 4) * 92}px;font-size:16px">{n}</div>'
    # bars
    h += '<div class="abs cap" style="left:60px;top:480px;font-size:18px;font-weight:600;color:#cfe6ff">BARS</div>'
    for i, (n, k, p) in enumerate([("HP", "hp", 78), ("Foe HP", "hpe", 55), ("SP", "spb", 100), ("XP", "xpb", 30), ("Momentum", "mom", 60)]):
        h += f'<div class="abs cap" style="left:60px;top:{514 + i * 38}px;width:110px;font-size:18px">{n}</div>' + bar(170, 520 + i * 38, 320, p, k)
    # buttons
    h += '<div class="abs cap" style="left:60px;top:730px;font-size:18px;font-weight:600;color:#cfe6ff">COMMAND BARS</div>'
    for i, (n, cls, ic) in enumerate([("Normal", "", "move"), ("Lit (selected)", "lit", "attack"), ("Muted (cannot use)", "off", "items")]):
        h += cmd(60, 764 + i * 46, n, ic, cls, i == 1, 430)
    # panels
    h += '<div class="abs cap" style="left:600px;top:160px;font-size:18px;font-weight:600;color:#cfe6ff">PANELS · TABS · CHIPS</div>'
    h += plate(600, 194, 380, 150, '<div class="abs cin" style="left:24px;top:16px;font-size:22px;color:#cfe6ff;letter-spacing:.12em">PANEL</div><div class="rule" style="left:24px;top:52px;width:330px"></div><div class="abs" style="left:24px;top:66px;font-size:19px;color:#c4d0de;width:330px">Chamfered corners, a thin steel edge, a faint light on the upper lip.</div>', 14)
    h += plate(1010, 194, 380, 150, '<div class="abs cin" style="left:24px;top:16px;font-size:22px;color:#f0f6ff;letter-spacing:.12em">LIT PANEL</div><div class="abs" style="left:24px;top:66px;font-size:19px;color:#dbe9f7;width:330px">The acting unit, the open tab, the selected card: the one thing that glows.</div>', 14, "lit")
    h += caption_tab(600, 370, 150, "CAPTION")
    for i, (t, c) in enumerate([("All 6", "lit"), ("Physical 3", ""), ("Holy 2", "")]):
        h += hexbar(770 + i * 150, 368, 140, 34, f'<div class="chip" style="inset:0">{t}</div>', c)
    h += chip(600, 426, 120, "Marked 1") + chip(730, 426, 120, "Learning", "lit") + chip(860, 426, 130, "Rank E")
    h += '<div class="abs cap" style="left:600px;top:480px;font-size:18px;font-weight:600;color:#cfe6ff">TYPE</div>'
    h += '<div class="abs cin" style="left:600px;top:508px;font-size:40px;color:#f0f6ff">TURN 1 · Cinzel Bold</div>'
    h += '<div class="abs" style="left:600px;top:566px;font-size:24px;font-weight:600">Inter SemiBold 24 · skill names, buttons</div><div class="abs" style="left:600px;top:604px;font-size:20px;font-weight:500;color:#c4d0de">Inter Medium 20 · body text, descriptions, objectives</div><div class="abs" style="left:600px;top:638px;font-size:16px;color:#8b9aad">Inter 16 · captions (nothing smaller)</div>'
    # motion and sound
    h += '<div class="abs cap" style="left:1450px;top:160px;font-size:18px;font-weight:600;color:#cfe6ff">MOTION AND SOUND</div>'
    spec = [("Selection change", "120 ms smooth glide of the lit bar"), ("Selected border", "gentle, steady light (a slow breath)"), ("Confirm", "brief 80 ms bright flash"),
            ("Submenu opening", "150 ms slide and fade, in the bars' place"), ("Disabled command", "muted steel, no glow"), ("Menu sound", "quiet metallic tick; soft metallic click"), ("Texture", "faint brushed steel, lit bar only")]
    for i, (a, b) in enumerate(spec):
        h += f'<div class="abs" style="left:1450px;top:{196 + i * 58}px;font-size:19px;font-weight:700;color:#e6eef8">{a}</div><div class="abs" style="left:1450px;top:{222 + i * 58}px;font-size:18px;color:#9eacbd;width:420px">{b}</div>'
    h += '</div>'
    return h


def main():
    body = frame1() + frame2() + frame3()
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>Steel HUD mockup</title><style>{CSS}</style></head><body>{body}</body></html>'
    open(os.path.join(HERE, "index.html"), "w", encoding="utf-8").write(html)
    print("wrote index.html (%d KB)" % (len(html) // 1024))


if __name__ == "__main__":
    main()
