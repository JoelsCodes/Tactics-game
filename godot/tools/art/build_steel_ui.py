#!/usr/bin/env python3
"""The battle HUD's steel look (Nov 2026, from docs/mockups/steel_hud): nine-slice textures with chamfered corners, written to assets/ui/steel_*.png.

    python3 godot/tools/art/build_steel_ui.py

steel_panel / steel_lit  the big panel, unlit and lit (a navy-to-slate fill, a thin icy edge)
steel_card / steel_card_lit  the small queue card
steel_tab                a caption tab (a hexagon: the points at mid-height), stretched in width
steel_portrait           a thin ring (transparent centre) that is tinted with a side's colour
steel_divider            a thin line with a diamond, for a panel's dividers
steel_banner             the TURN banner: an arrow-pointing plate
Everything is drawn at 4x and reduced, so the chamfers are clean. The tabs and cards are meant for StyleBoxTexture with the margins HudStyle gives them.
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "ui")
S = 4  # supersample


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hexv(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def chamfer_poly(w, h, c, inset=0):
    a = inset
    return [(a, a + c), (a + c, a), (w - a - c, a), (w - a, a + c), (w - a, h - a - c), (w - a - c, h - a), (a + c, h - a), (a, h - a - c)]


def vgrad(size, top, bot, alpha=255):
    w, h = size
    im = Image.new("RGBA", size)
    px = im.load()
    for y in range(h):
        col = lerp(top, bot, y / max(h - 1, 1)) + (alpha,)
        for x in range(w):
            px[x, y] = col
    return im


def plate(w, h, c, edge_top, edge_bot, fill_top, fill_bot, alpha=250, hi=True):
    """A chamfered plate with a 1 px edge gradient and a vertical fill."""
    W, H = w * S, h * S
    mask_o = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask_o).polygon(chamfer_poly(W, H, c * S), fill=255)
    mask_i = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask_i).polygon(chamfer_poly(W, H, c * S - S, S), fill=255)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(vgrad((W, H), edge_top, edge_bot), (0, 0), mask_o)
    inner = vgrad((W, H), fill_top, fill_bot, alpha)
    if hi:  # a faint light along the upper lip
        d = ImageDraw.Draw(inner)
        d.line([(c * S, S + S // 2), (W - c * S, S + S // 2)], fill=(190, 215, 255, 30), width=S)
    out.paste(inner, (0, 0), mask_i)
    return out.resize((w, h), Image.LANCZOS)


def hexplate(w, h, edge_top, edge_bot, fill_top, fill_bot, alpha=250):
    W, H = w * S, h * S
    t = H // 2
    outer = [(0, H // 2), (t, 0), (W - t, 0), (W, H // 2), (W - t, H), (t, H)]
    inner = [(S, H // 2), (t + S // 2, S), (W - t - S // 2, S), (W - S, H // 2), (W - t - S // 2, H - S), (t + S // 2, H - S)]
    mo = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mo).polygon(outer, fill=255)
    mi = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mi).polygon(inner, fill=255)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(vgrad((W, H), edge_top, edge_bot), (0, 0), mo)
    out.paste(vgrad((W, H), fill_top, fill_bot, alpha), (0, 0), mi)
    return out.resize((w, h), Image.LANCZOS)


def save(im, name):
    im.save(os.path.join(OUT, name))
    print(name, im.size)


def main():
    steel_edge = (hexv("#60758e"), hexv("#2a3646"))
    steel_fill = (hexv("#19222d"), hexv("#0d131a"))
    lit_edge = (hexv("#b9e6ff"), hexv("#5aa9e0"))
    lit_fill = (hexv("#0b1d3a"), hexv("#2d4a6f"))
    save(plate(64, 64, 12, *steel_edge, *steel_fill, alpha=246), "steel_panel.png")
    save(plate(64, 64, 12, *lit_edge, *lit_fill, alpha=250), "steel_lit.png")
    save(plate(40, 40, 8, *steel_edge, *steel_fill, alpha=250, hi=False), "steel_card.png")
    save(plate(40, 40, 8, *lit_edge, *lit_fill, alpha=252, hi=False), "steel_card_lit.png")
    save(hexplate(96, 34, hexv("#566a82"), hexv("#222c39"), hexv("#151c26"), hexv("#1f2834")), "steel_tab.png")
    save(hexplate(96, 34, hexv("#c8ecff"), hexv("#6fb7ec"), hexv("#0b1d3a"), hexv("#2d4a6f")), "steel_tab_lit.png")
    save(hexplate(96, 34, hexv("#3a424c"), hexv("#2c333c"), hexv("#262d35"), hexv("#2c323b")), "steel_tab_off.png")
    for name, sgn in (("l", -1), ("r", 1)):  # the turn bar's arrows: a thin ice chevron
        AW, AH = 28 * S, 62 * S
        arr = Image.new("RGBA", (AW, AH), (0, 0, 0, 0))
        ad = ImageDraw.Draw(arr)
        cx, cy, k = AW // 2, AH // 2, 7 * S
        pts = [(cx - sgn * k // 2, cy - 2 * k), (cx + sgn * k // 2, cy), (cx - sgn * k // 2, cy + 2 * k)]
        ad.line(pts, fill=(143, 212, 255, 255), width=3 * S, joint="curve")
        save(arr.resize((28, 62), Image.LANCZOS), "steel_arrow_%s.png" % name)
    # the portrait ring: an edge only, tinted by the side's colour
    W = 40 * S
    ring = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(ring)
    d.polygon(chamfer_poly(W, W, 8 * S), fill=255)
    d.polygon(chamfer_poly(W, W, 8 * S - 2 * S, 2 * S), fill=0)
    rim = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    rim.putalpha(ring)
    save(rim.resize((40, 40), Image.LANCZOS), "steel_portrait.png")
    # the divider: a thin line fading out at both ends, a diamond in the middle
    DW, DH = 380 * S, 9 * S
    div = Image.new("RGBA", (DW, DH), (0, 0, 0, 0))
    px = div.load()
    mid = DH // 2
    for x in range(DW):
        a = int(110 * min(1.0, x / (DW * 0.25), (DW - x) / (DW * 0.25)))
        for dy in range(S):
            px[x, mid - S // 2 + dy] = (143, 180, 212, a)
    dd = ImageDraw.Draw(div)
    cx = DW // 2
    dd.polygon([(cx, mid - 4 * S), (cx + 4 * S, mid), (cx, mid + 4 * S), (cx - 4 * S, mid)], fill=(143, 180, 212, 150))
    save(div.resize((380, 9), Image.LANCZOS), "steel_divider.png")
    # the TURN banner: a plate ending in a point on the right
    BW, BH = 436 * S, 62 * S
    p = [(0, 0), (BW - 30 * S, 0), (BW, BH // 2), (BW - 30 * S, BH), (0, BH)]
    pi = [(0, S), (BW - 30 * S - S // 2, S), (BW - S, BH // 2), (BW - 30 * S - S // 2, BH - S), (0, BH - S)]
    mo = Image.new("L", (BW, BH), 0)
    ImageDraw.Draw(mo).polygon(p, fill=255)
    mi = Image.new("L", (BW, BH), 0)
    ImageDraw.Draw(mi).polygon(pi, fill=255)
    ban = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    ban.paste(vgrad((BW, BH), hexv("#566a82"), hexv("#222c39")), (0, 0), mo)
    ban.paste(vgrad((BW, BH), hexv("#19222d"), hexv("#0d131a"), 250), (0, 0), mi)
    save(ban.resize((436, 62), Image.LANCZOS), "steel_banner.png")


if __name__ == "__main__":
    main()
