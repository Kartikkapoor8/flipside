# Flipside UI mockups — shared components (HTML/CSS strings, rendered by headless Chrome).
# Brand values come from ../../brand/tokens.json; deck copy from ../../deck/deck.json.
import json, os, subprocess, shutil, time, uuid, itertools
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent.parent            # ~/flipside-assets
UI = HERE.parent                       # ~/flipside-assets/ui
HTML_DIR = HERE / "html"
RAW = UI / "raw"
_tok_snap = HERE / "tokens-snapshot.json"
_deck_snap = HERE / "deck-snapshot.json"
TOK = json.load(open(_tok_snap if _tok_snap.exists() else ASSETS / "brand" / "tokens.json"))
DECK = json.load(open(_deck_snap if _deck_snap.exists() else ASSETS / "deck" / "deck.json"))
for _s in DECK:  # tolerate missing fields while the deck job is still editing
    _s.setdefault("title", "Untitled"); _s.setdefault("body", ""); _s.setdefault("notes", ""); _s.setdefault("cue", "next"); _s.setdefault("layout", "statement"); _s.setdefault("durationHint", 30)

C = dict(
    paper=TOK["color"]["audience"]["background"]["hex"],
    card=TOK["color"]["audience"]["surface"]["hex"],
    ink=TOK["color"]["audience"]["text"]["hex"],
    graphite=TOK["color"]["audience"]["muted"]["hex"],
    verd=TOK["color"]["audience"]["accent"]["hex"],
    slate=TOK["color"]["presenter"]["surface"]["hex"],
    ash=TOK["color"]["presenter"]["muted"]["hex"],
    verdl=TOK["color"]["presenter"]["accent"]["hex"],
    crease_l=TOK["color"]["crease"]["light"],
    crease_d=TOK["color"]["crease"]["dark"],
    laser="#FF3B30",           # the one non-palette colour: the laser dot (documented in DECISIONS.md)
)

# Display geometry (points). Inner: 669 x 951 pt @3x = 2007 x 2853 px (simulator framebuffer). Hinge horizontal at 475.5.
INNER_W, INNER_H = 669, 951
HALF_H = 475.5
GUTTER = 16            # assumed half-width of the folding reserved region (pt) — read ReservedRegion(.division) at runtime
OUTER_W, OUTER_H = 466, 678
IPHONE_W, IPHONE_H = 402, 874

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

_ids = itertools.count(1)

BASE_CSS = """
@font-face{font-family:"Instrument Serif";src:url("fonts/InstrumentSerif-Regular.ttf");font-weight:400;font-style:normal}
@font-face{font-family:"Instrument Serif";src:url("fonts/InstrumentSerif-Italic.ttf");font-weight:400;font-style:italic}
:root{--paper:%(paper)s;--card:%(card)s;--ink:%(ink)s;--graphite:%(graphite)s;--verd:%(verd)s;--slate:%(slate)s;--ash:%(ash)s;--verdl:%(verdl)s;
--crease-l:%(crease_l)s;--crease-d:%(crease_d)s;--laser:%(laser)s;
--sans:-apple-system,"SF Pro Text","SF Pro Display",system-ui,"Helvetica Neue",sans-serif;
--serif:"Instrument Serif","New York",Georgia,serif;}
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:transparent}
body{font-family:var(--sans);-webkit-font-smoothing:antialiased;color:var(--ink);font-feature-settings:"tnum" 0}
.tn{font-variant-numeric:tabular-nums}
.abs{position:absolute}
.row{display:flex;align-items:center}
.col{display:flex;flex-direction:column}
.lbl{font:500 11px/13px var(--sans);letter-spacing:.07em;text-transform:uppercase;color:var(--ash)}
""" % C

# ---------------------------------------------------------------- icons / mark
# Brand mark v0.2.0: the phone in tent mode seen from the audience side. Notes face (ink) reclines behind the ridge, slide face (accent) stands steep.
MARK_NOTES = "M75.03 48.56 L16.38 40.22 L27.36 24.81 L86.00 33.15 Z"
MARK_SLIDE = "M16.38 40.22 L75.03 48.56 L72.64 75.19 L14.00 66.85 Z"

def mark(size, dark=False, style=""):
    ink = C["paper"] if dark else C["ink"]
    acc = C["verdl"] if dark else C["verd"]
    return ('<svg width="%s" height="%s" viewBox="0 0 100 100" style="display:block;flex:none;%s">'
            '<path d="%s" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>'
            '<path d="%s" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/></svg>'
            % (size, size, style, MARK_NOTES, ink, ink, MARK_SLIDE, acc, acc))

def wordmark(h, dark=False, style=""):
    col = C["paper"] if dark else C["ink"]
    return ('<div class="row" style="gap:%spx;%s">%s<span style="font:400 %spx/1 var(--serif);color:%s;letter-spacing:-.01em;position:relative;top:%spx">Flipside</span></div>'
            % (round(h*0.12), style, mark(h, dark), round(h*0.92), col, round(h*0.02)))

def svg(path, size=18, color="currentColor", sw=1.8, vb=24, fill="none", style=""):
    return ('<svg width="%s" height="%s" viewBox="0 0 %s %s" fill="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round" style="display:block;flex:none;%s">%s</svg>'
            % (size, size, vb, vb, fill, color, sw, style, path))

ICON = dict(
    chev_l='<path d="M15 5l-7 7 7 7"/>',
    chev_r='<path d="M9 5l7 7-7 7"/>',
    mic='<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
    check='<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    clock='<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    textfmt='<path d="M5 19l5.5-14h3L19 19M7.5 14h9"/>',
    list='<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1" fill="currentColor"/><circle cx="4.5" cy="12" r="1" fill="currentColor"/><circle cx="4.5" cy="18" r="1" fill="currentColor"/>',
    dots='<circle cx="5" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
    reply='<path d="M9 7L4 12l5 5M4 12h9a6 6 0 0 1 6 6v1"/>',
    trash='<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>',
    archive='<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10h14V9M10 13h4"/>',
    compose='<path d="M4 20h4l11-11-4-4L4 16v4zM13 7l4 4"/>',
    up='<path d="M6 15l6-6 6 6"/>',
    down='<path d="M6 9l6 6 6-6"/>',
    laser='<circle cx="12" cy="12" r="3.5" fill="currentColor" stroke="none"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.2 2.2M16.2 16.2l2.2 2.2M5.6 18.4l2.2-2.2M16.2 7.8l2.2-2.2"/>',
    grip='<circle cx="9" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="18" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="18" r="1.4" fill="currentColor" stroke="none"/>',
    plus='<path d="M12 5v14M5 12h14"/>',
)

def wave(color, h=14, bars=(0.35, 0.8, 1, 0.55, 0.85, 0.4), w=3, gap=3, style=""):
    total = len(bars) * w + (len(bars) - 1) * gap
    b = "".join('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"/>' % (i*(w+gap), h*(1-f)/2, w, h*f, w/2, color) for i, f in enumerate(bars))
    return '<svg width="%s" height="%s" viewBox="0 0 %s %s" style="display:block;flex:none;%s">%s</svg>' % (total, h, total, h, style, b)

def status_icons(color, size=1.0):
    # cellular, wifi, battery — drawn, iOS-ish
    return ('<div class="row" style="gap:7px;transform:scale(%s);transform-origin:right center">' % size +
            '<svg width="19" height="12" viewBox="0 0 19 12" fill="%s"><rect x="0" y="8" width="3.5" height="4" rx="1"/><rect x="5" y="5.5" width="3.5" height="6.5" rx="1"/><rect x="10" y="3" width="3.5" height="9" rx="1"/><rect x="15" y="0" width="3.5" height="12" rx="1"/></svg>' % color +
            '<svg width="17" height="12" viewBox="0 0 17 12" fill="none" stroke="%s" stroke-width="1.9" stroke-linecap="round"><path d="M1.5 4.2a10 10 0 0 1 14 0M4.2 7a6.2 6.2 0 0 1 8.6 0"/><circle cx="8.5" cy="10" r="1.4" fill="%s" stroke="none"/></svg>' % (color, color) +
            '<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".7" y=".7" width="22.6" height="11.6" rx="3.5" fill="none" stroke="%s" stroke-opacity=".45" stroke-width="1.2"/><rect x="2.4" y="2.4" width="17" height="8.2" rx="2" fill="%s"/><path d="M25 4.5v4a2.2 2.2 0 0 0 0-4z" fill="%s" fill-opacity=".45"/></svg>' % (color, color, color) +
            '</div>')

# ---------------------------------------------------------------- slides (1200 x 630 canvas, brand templates)
SLIDE_CSS = """
.sl{width:1200px;height:630px;position:relative;overflow:hidden;background:var(--paper);color:var(--ink);font-family:var(--sans)}
.sl .f{position:absolute;top:0;bottom:0;width:600px}
.sl .f.l{left:0}.sl .f.r{left:600px}
.sl .f.lit{background:var(--card)}
.sl .cr{position:absolute;left:599.5px;top:0;bottom:0;width:1px;background:var(--crease-l)}
.sl .tab{position:absolute;left:598.5px;top:0;width:3px;height:28px;background:var(--verd)}
.sl .mk{position:absolute;left:40px;top:34px}
.sl .ls{position:absolute;left:64px;bottom:40px;display:flex;align-items:center;gap:8px;font:500 15px/1 var(--sans);color:var(--graphite);letter-spacing:.02em}
.sl .ls i{display:block;width:8px;height:8px;border-radius:50%;background:var(--verd)}
.sl .nm{position:absolute;right:64px;bottom:40px;font:500 15px/1 var(--sans);color:var(--graphite);font-variant-numeric:tabular-nums}
.sl .in{position:absolute;left:64px;right:56px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;gap:22px}
.sl .f.r .in{left:64px;right:64px}
.sl .in.c{align-items:center;text-align:center}
.sl .t{font:400 96px/1 var(--serif);letter-spacing:-.01em}
.sl .t2{font:400 60px/1.06 var(--serif);letter-spacing:-.008em}
.sl .t2.it{font-style:italic}
.sl .t3{font:400 52px/1.1 var(--serif);letter-spacing:-.006em}
.sl .b{font:400 25px/1.42 var(--sans);color:var(--graphite)}
.sl .lb{font:500 16px/1 var(--sans);letter-spacing:.07em;text-transform:uppercase;color:var(--graphite)}
.sl .num{position:absolute;left:64px;top:64px;font:400 44px/1 var(--serif);color:var(--graphite)}
.sl .dg{display:flex;gap:22px;align-items:stretch}
.sl .dgc{flex:1;display:flex;flex-direction:column;gap:12px}
.sl .dgcr{width:1px;background:rgba(17,20,24,.2);align-self:stretch;margin-top:28px}
.sl .mini{height:156px;border-radius:12px;padding:18px;position:relative;border:1px solid var(--crease-l)}
.sl .mini.light{background:var(--paper)}
.sl .mini.dark{background:var(--ink);border-color:transparent}
.sl .mt{font:400 24px/1.1 var(--serif);color:var(--ink);margin-bottom:6px}
.sl .ml{height:8px;border-radius:4px;background:rgba(17,20,24,.14);margin-top:10px;width:78%}
.sl .ml.s{width:52%}
.sl .mini.dark .ml{background:rgba(241,242,244,.22)}
.sl .mtm{position:absolute;right:16px;bottom:14px;font:600 20px/1 var(--sans);color:var(--verdl);font-variant-numeric:tabular-nums}
.sl .pill{display:inline-flex;align-items:center;gap:14px;padding:18px 28px;border-radius:999px;background:var(--card);border:1px solid var(--crease-l);font:400 24px/1 var(--sans);color:var(--graphite);white-space:nowrap}
.sl .pill .pc{color:var(--ink);font-weight:600}
.sl .fld{display:flex;align-items:center;gap:12px;height:64px;border-radius:14px;background:var(--paper);border:1px solid var(--crease-l);padding:0 20px;font:400 22px/1 var(--sans);color:var(--graphite)}
.sl .caret{width:2px;height:28px;background:var(--verd)}
.sl .slots{display:flex;gap:12px}
.sl .slot{flex:1;height:96px;border:1.5px dashed rgba(17,20,24,.22);border-radius:10px;display:flex;align-items:center;justify-content:center;font:400 24px/1 var(--serif);color:var(--graphite)}
.sl .cc{position:absolute;left:0;right:0;top:262px;text-align:center;padding:0 150px;display:flex;flex-direction:column;gap:22px;align-items:center}
.sl .cr.seg1{bottom:auto;height:118px}.sl .cr.seg2{top:auto;height:130px}
"""

def slide_html(i):
    """Slide i (1-based) from deck.json, on the brand templates. Returns a 1200x630 .sl div."""
    s = DECK[i-1]
    n = len(DECK)
    chrome = '<div class="cr"></div><div class="tab"></div><div class="ls"><i></i>listening</div><div class="nm">%d / %d</div>' % (i, n)
    lay = s["layout"]
    if lay == "cover":
        return ('<div class="sl"><div class="f l lit"><div class="in">%s<div class="t">%s</div><div class="b" style="max-width:440px">%s</div></div></div><div class="f r"></div>%s</div>'
                % (mark(64), s["title"], s["body"], chrome))
    if lay not in ("statement", "split", "listen", "live", "close"):
        lay = "statement"
    if lay == "statement":
        return ('<div class="sl"><div class="f l"><div class="num">%02d</div></div><div class="f r lit"><div class="in"><div class="t2 it">%s</div><div class="b">%s</div></div></div>%s%s</div>'
                % (i, s["title"], s["body"], chrome, '<div class="mk">%s</div>' % mark(30)))
    if lay == "split":
        dg = ('<div class="dg"><div class="dgc"><div class="lb">Public face</div><div class="mini light"><div class="mt">The slide</div><div class="ml"></div><div class="ml s"></div><div class="ml"></div></div></div>'
              '<div class="dgcr"></div>'
              '<div class="dgc"><div class="lb">Private face</div><div class="mini dark"><div class="ml" style="width:60%%;margin-top:4px"></div><div class="ml"></div><div class="ml s"></div><div class="mtm">01:38</div></div></div></div>')
        t = s["title"].replace(". ", ".<br>", 1)
        return ('<div class="sl"><div class="f l lit"><div class="in"><div class="t2">%s</div><div class="b">%s</div></div></div><div class="f r lit"><div class="in">%s</div></div>%s%s</div>'
                % (t, s["body"], dg, chrome, '<div class="mk">%s</div>' % mark(30)))
    if lay == "listen":
        pill = '<div class="pill">%s<span>listening for</span><span class="pc">“%s”</span></div>' % (wave(C["verd"], 22, w=4, gap=4), s["cue"])
        return ('<div class="sl"><div class="f l lit"><div class="in"><div class="t2">%s</div><div class="b">%s</div></div></div><div class="f r"><div class="in c">%s<div class="b" style="font-size:19px;max-width:360px">Say it in the flow of your talk. Nothing to tap.</div></div></div>%s%s</div>'
                % (s["title"], s["body"], pill, chrome, '<div class="mk">%s</div>' % mark(30)))
    if lay == "live":
        right = ('<div class="in"><div class="lb">Topic</div><div class="fld">%s<span>listening for a topic</span><i class="caret"></i></div><div class="lb" style="margin-top:6px">Three slides, written live</div><div class="slots"><div class="slot">1</div><div class="slot">2</div><div class="slot">3</div></div></div>'
                 % svg(ICON["mic"], 24, C["verd"], 2))
        return ('<div class="sl"><div class="f l lit"><div class="in"><div class="t2">%s</div><div class="b">%s</div></div></div><div class="f r lit">%s</div>%s%s</div>'
                % (s["title"], s["body"], right, chrome, '<div class="mk">%s</div>' % mark(30)))
    if lay == "close":
        chrome2 = '<div class="cr seg1"></div><div class="cr seg2"></div><div class="tab"></div><div class="ls"><i></i>listening</div><div class="nm">%d / %d</div>' % (i, n)
        return ('<div class="sl"><div class="f l"></div><div class="f r"></div><div class="abs" style="left:564px;top:150px">%s</div><div class="cc"><div class="t3">%s</div><div class="b" style="max-width:640px">%s</div></div>%s</div>'
                % (mark(72), s["title"], s["body"], chrome2))
    raise ValueError(lay)

def slidebox(i, w, radius=8, border=True, style="", cls=""):
    k = w / 1200.0
    h = round(w * 630 / 1200.0, 2)
    b = "border:1px solid var(--crease-l);" if border else ""
    return ('<div class="slidebox %s" style="width:%spx;height:%spx;overflow:hidden;border-radius:%spx;position:relative;%s%s">'
            '<div style="width:1200px;height:630px;transform:scale(%s);transform-origin:0 0">%s</div></div>' % (cls, w, h, radius, b, style, k, slide_html(i)))

# ---------------------------------------------------------------- presenter half (669 x 475.5, dark, upright)
PRES_CSS = """
.pres{width:669px;height:475.5px;background:var(--ink);color:var(--paper);position:relative;overflow:hidden;font-family:var(--sans)}
.pres .hdr{position:absolute;left:20px;right:20px;top:14px;height:46px;display:flex;align-items:center;justify-content:space-between}
.pres .hl{display:flex;align-items:center;gap:12px}
.pres .st{font:600 15px/18px var(--sans);color:var(--paper);max-width:250px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pres .timer{font:600 34px/34px var(--sans);letter-spacing:-.01em;font-variant-numeric:tabular-nums;color:var(--paper);text-align:center}
.pres .tsub{font:500 11px/13px var(--sans);color:var(--ash);text-align:center;margin-top:3px;font-variant-numeric:tabular-nums}
.pres .nav{display:flex;align-items:center;height:36px;border-radius:18px;background:var(--slate);overflow:hidden}
.pres .nav .bt{width:42px;height:36px;display:flex;align-items:center;justify-content:center;color:var(--paper)}
.pres .nav .ct{font:600 13px/1 var(--sans);color:var(--ash);font-variant-numeric:tabular-nums;padding:0 4px}
.pres .end{height:36px;padding:0 14px;border-radius:18px;background:var(--slate);color:var(--ash);font:600 13px/36px var(--sans);margin-left:8px}
.pres .body{position:absolute;left:20px;right:20px;top:72px;height:371px}
.pres .notes{position:absolute;left:0;top:0;width:416px;height:371px;background:var(--slate);border-radius:14px;padding:16px 18px}
.pres .ntext{font:400 17px/26px var(--sans);color:var(--paper);margin-top:8px}
.pres .cue{position:absolute;left:18px;right:18px;bottom:16px;padding-top:14px;border-top:1px solid var(--crease-d)}
.pres .cuep{font:600 26px/30px var(--sans);color:var(--verdl);margin-top:6px;letter-spacing:-.005em}
.pres .listen{display:flex;align-items:center;gap:8px;margin-top:8px;font:500 12px/14px var(--sans);color:var(--ash)}
.pres .rc{position:absolute;left:432px;top:0;width:197px;height:371px}
.pres .nextcap{font:400 12px/14px var(--sans);color:var(--ash);margin-top:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pres .pad{position:absolute;left:0;right:0;top:154px;bottom:0;border-radius:14px;background-color:var(--slate);background-image:radial-gradient(rgba(241,242,244,.11) 1px,transparent 1.2px);background-size:14px 14px;background-position:7px 7px;border:1.5px solid rgba(241,242,244,.06)}
.pres .pad.on{border-color:var(--verdl);box-shadow:0 0 0 3px rgba(70,169,143,.18)}
.pres .padl{position:absolute;left:12px;top:10px;display:flex;align-items:center;gap:6px}
.pres .padh{position:absolute;left:0;right:0;top:50%;margin-top:-8px;text-align:center;font:400 13px/16px var(--sans);color:var(--ash)}
.pres .ring{position:absolute;width:46px;height:46px;border-radius:50%;border:2px solid rgba(241,242,244,.85);margin:-23px 0 0 -23px;box-shadow:0 0 0 6px rgba(241,242,244,.12)}
.pres .ring i{position:absolute;left:50%;top:50%;width:8px;height:8px;margin:-4px 0 0 -4px;border-radius:50%;background:var(--laser)}
"""

def presenter_half(cur=3, elapsed="01:38", slide_elapsed="0:22", laser=None, style=""):
    s = DECK[cur-1]; n = len(DECK)
    nxt = DECK[cur] if cur < n else None
    hint = "%d:%02d" % divmod(int(s.get("durationHint", 30)), 60)
    laser_html = ""
    pad_cls = "pad"
    hint_html = '<div class="padh">Touch to point</div>'
    if laser:
        u, v = laser
        pad_cls = "pad on"
        hint_html = ""
        laser_html = '<div class="ring" style="left:%s%%;top:%s%%"><i></i></div>' % (u*100, v*100)
    next_html = ('<div class="lbl">Next · %d</div>%s<div class="nextcap">%s</div>' % (cur+1, slidebox(cur+1, 197, 8, True, "margin-top:6px;border-color:var(--crease-d)"), nxt["title"])
                 if nxt else '<div class="lbl">Next</div><div style="margin-top:6px;height:103px;border-radius:8px;border:1px dashed var(--crease-d);display:flex;align-items:center;justify-content:center;font:400 13px/1 var(--sans);color:var(--ash)">close the phone</div>')
    if s["cue"]:
        cue_html = '<div class="cue"><div class="lbl">Say to advance</div><div class="cuep">“%s”</div><div class="listen">%s listening</div></div>' % (s["cue"], wave(C["verdl"], 12))
    else:   # slide 6: no cue on purpose; folding the phone ends the run
        cue_html = '<div class="cue"><div class="lbl">To end</div><div class="cuep">Close the phone</div><div class="listen">%s nothing to say · the fold sends the recap</div></div>' % svg(ICON["check"], 14, C["verdl"], 2.2)
    return ('<div class="pres" style="%s">'
            '<div class="hdr"><div class="hl">%s<div><div class="lbl">Slide %d of %d</div><div class="st">%s</div></div></div>'
            '<div><div class="timer">%s</div><div class="tsub">%s / %s on this slide</div></div>'
            '<div class="row"><div class="nav"><div class="bt">%s</div><div class="ct">%d / %d</div><div class="bt">%s</div></div><div class="end">End</div></div></div>'
            '<div class="body"><div class="notes"><div class="lbl">Notes</div><div class="ntext">%s</div>%s</div>'
            '<div class="rc">%s<div class="%s"><div class="padl">%s<span class="lbl">Laser</span></div>%s%s</div></div></div></div>'
            % (style, mark(24, True), cur, n, s["title"], elapsed, slide_elapsed, hint,
               svg(ICON["chev_l"], 18, C["paper"], 2), cur, n, svg(ICON["chev_r"], 18, C["paper"], 2),
               s["notes"], cue_html,
               next_html, pad_cls, svg(ICON["laser"], 13, C["laser"], 1.6), hint_html, laser_html))

# ---------------------------------------------------------------- audience half (669 x 475.5, light). Content is upright; the caller rotates it.
AUD_CSS = """
.aud{width:669px;height:475.5px;background:var(--paper);position:relative;overflow:hidden;font-family:var(--sans)}
.aud .slidebox{box-shadow:0 1px 0 rgba(17,20,24,.04)}
.aud .prog{position:absolute;left:16px;right:16px;top:378px;display:flex;gap:4px}
.aud .prog i{flex:1;height:3px;border-radius:2px;background:rgba(17,20,24,.10)}
.aud .prog i.on{background:var(--verd)}
.aud .prog i.done{background:rgba(14,107,94,.35)}
.aud .dot{position:absolute;width:16px;height:16px;margin:-8px 0 0 -8px;border-radius:50%;background:var(--laser);box-shadow:0 0 0 3px rgba(255,59,48,.28),0 0 18px 6px rgba(255,59,48,.45)}
.aud .dot:after{content:"";position:absolute;left:4px;top:4px;width:5px;height:5px;border-radius:50%;background:rgba(255,255,255,.75)}
"""

def audience_half(cur=3, laser=None, style=""):
    n = len(DECK)
    prog = "".join('<i class="%s"></i>' % ("on" if i == cur else "done" if i < cur else "") for i in range(1, n+1))
    dot = ""
    if laser:
        u, v = laser
        dot = '<div class="dot" style="left:%spx;top:%spx"></div>' % (round(16 + u*637, 1), round(30 + v*334.4, 1))
    return ('<div class="aud" style="%s">%s<div class="prog">%s</div>%s</div>'
            % (style, slidebox(cur, 637, 10, True, "position:absolute;left:16px;top:30px"), prog, dot))

# ---------------------------------------------------------------- full inner screen (669 x 951)
def present_screen(cur=3, laser=None, aud_rot=180):
    return ('<div class="screen" style="width:669px;height:951px;position:relative;overflow:hidden;background:#000">'
            '<div class="abs" style="left:0;top:0">%s</div>'
            '<div class="abs" style="left:0;top:475.5px;transform:rotate(%sdeg)">%s</div></div>'
            % (presenter_half(cur, laser=laser), aud_rot, audience_half(cur, laser=laser)))

# ---------------------------------------------------------------- edit mode (669 x 951, flat, portrait; grid on the far half, editor on the near half)
EDIT_CSS = """
.edit{width:669px;height:951px;background:var(--ink);color:var(--paper);position:relative;overflow:hidden;font-family:var(--sans)}
.edit .sb{position:absolute;left:0;right:0;top:0;height:50px;display:flex;align-items:center;justify-content:space-between;padding:0 28px 0 30px;font:600 15px/1 var(--sans);font-variant-numeric:tabular-nums}
.edit .nb{position:absolute;left:20px;right:20px;top:56px;height:44px;display:flex;align-items:center;justify-content:space-between}
.edit .gp{height:36px;border-radius:18px;background:var(--slate);display:flex;align-items:center;gap:4px;padding:0 14px 0 8px;font:500 15px/1 var(--sans);color:var(--paper)}
.edit .ttl{text-align:center}
.edit .ttl b{display:block;font:600 17px/20px var(--sans)}
.edit .ttl span{display:block;font:400 12px/14px var(--sans);color:var(--ash);margin-top:2px}
.edit .pr{height:36px;border-radius:18px;background:var(--verdl);color:var(--ink);font:600 15px/36px var(--sans);padding:0 16px}
.edit .more{width:36px;height:36px;border-radius:18px;background:var(--slate);display:flex;align-items:center;justify-content:center;margin-left:8px}
.edit .grid{position:absolute;left:34.5px;top:116px;width:600px;height:327px}
.edit .tile{position:absolute;width:192px;height:100.8px}
.edit .tile .slidebox{border-color:var(--crease-d)!important}
.edit .tile .bd{position:absolute;left:6px;bottom:6px;height:20px;min-width:20px;padding:0 6px;border-radius:10px;background:rgba(17,20,24,.82);color:var(--paper);font:600 11px/20px var(--sans);text-align:center;font-variant-numeric:tabular-nums}
.edit .tile.sel .slidebox{outline:2px solid var(--verdl);outline-offset:0;box-shadow:0 0 0 5px rgba(70,169,143,.22)}
.edit .tile.lift{transform:scale(1.07) rotate(-2deg);z-index:5}
.edit .tile.lift .slidebox{box-shadow:0 18px 40px rgba(0,0,0,.6),0 0 0 1px rgba(241,242,244,.12)}
.edit .ghost{position:absolute;width:192px;height:100.8px;border-radius:8px;border:1.5px dashed rgba(241,242,244,.22)}
.edit .ins{position:absolute;width:3px;height:100.8px;border-radius:2px;background:var(--verdl);box-shadow:0 0 10px rgba(70,169,143,.8)}
.edit .new{position:absolute;width:192px;height:100.8px;border-radius:8px;border:1.5px dashed rgba(241,242,244,.22);display:flex;align-items:center;justify-content:center;gap:6px;font:500 13px/1 var(--sans);color:var(--ash)}
.edit .ed{position:absolute;left:20px;right:20px;top:497px}
.edit .edh{display:flex;align-items:flex-end;justify-content:space-between}
.edit .edh b{display:block;font:600 22px/26px var(--sans);margin-top:4px}
.edit .chip{height:32px;border-radius:16px;background:var(--slate);display:flex;align-items:center;gap:6px;padding:0 12px;font:600 13px/1 var(--sans);color:var(--paper);font-variant-numeric:tabular-nums}
.edit .ta{margin-top:14px;background:var(--slate);border-radius:14px;padding:16px 18px;font:400 17px/26px var(--sans);color:var(--paper);height:192px}
.edit .caret{display:inline-block;width:2px;height:20px;background:var(--verdl);vertical-align:-4px;margin-left:1px}
.edit .cuef{margin-top:8px;height:48px;border-radius:14px;background:var(--slate);display:flex;align-items:center;gap:10px;padding:0 14px 0 16px}
.edit .cuef b{flex:1;font:600 17px/1 var(--sans);color:var(--verdl)}
.edit .cuef span{font:500 13px/1 var(--sans);color:var(--ash);padding:6px 10px;border-radius:12px;border:1px solid var(--crease-d)}
.edit .tb{position:absolute;left:20px;right:20px;top:856px;height:44px;display:flex;align-items:center;justify-content:space-between}
.edit .tb .g{display:flex;gap:8px}
.edit .tb .k{height:36px;min-width:36px;padding:0 10px;border-radius:18px;background:var(--slate);display:flex;align-items:center;justify-content:center;gap:6px;font:500 13px/1 var(--sans);color:var(--paper)}
.edit .done{font:600 17px/1 var(--sans);color:var(--verdl)}
.edit .hi{position:absolute;left:267.5px;bottom:8px;width:134px;height:5px;border-radius:3px;background:rgba(241,242,244,.7)}
"""

def edit_screen(sel=3, drag=6, t=1.0, flying=None):
    """Edit layout. t<1 renders the transition frame (grid/editor chrome fade in, notes card and slide in flight)."""
    n = len(DECK)
    sel = min(sel, n); drag = min(drag, n)
    rows = max(3, -(-(n + 1) // 3))
    slots = [(c, r) for r in range(rows) for c in range(3)]
    order = list(range(1, n+1))
    # tile positions
    pos = {}
    for idx, i in enumerate(order):
        c, r = slots[idx]
        pos[i] = (c*204, r*(100.8+12.2))
    parts = []
    for i in order:
        x, y = pos[i]
        if t < 1 and i == sel:
            parts.append('<div class="ghost" style="left:%spx;top:%spx;border-color:var(--verdl);opacity:.9"></div>' % (x, y))
            continue
        if t >= 1 and i == drag:
            parts.append('<div class="ghost" style="left:%spx;top:%spx"></div>' % (x, y))
            continue
        cls = "tile" + (" sel" if i == sel else "")
        parts.append('<div class="%s" style="left:%spx;top:%spx">%s<div class="bd">%d</div></div>' % (cls, x, y, slidebox(i, 192, 8), i))
    # dragged tile hovers between the first two tiles of row 2, with an insertion bar peeking out above it
    if t >= 1 and n >= 5 and drag != sel:
        x4, y4 = pos[4]
        parts.append('<div class="ins" style="left:%spx;top:%spx"></div>' % (x4 + 192 + 4.5, y4))
        parts.append('<div class="tile lift" style="left:%spx;top:%spx">%s<div class="bd">%d</div></div>' % (x4 + 150, y4 + 26, slidebox(drag, 192, 8), drag))
    c, r = slots[n]
    parts.append('<div class="new" style="left:%spx;top:%spx">%s New slide</div>' % (c*204, r*113, svg(ICON["plus"], 14, C["ash"], 2)))
    grid = '<div class="grid" style="opacity:%s">%s</div>' % (t, "".join(parts))
    s = DECK[sel-1]
    hint = "%d:%02d" % divmod(int(s.get("durationHint", 30)), 60)
    chrome_op = max(0.0, (t - 0.5) / 0.5)
    top = ('<div class="sb" style="opacity:%s"><span>10:09</span>%s</div>'
           '<div class="nb" style="opacity:%s"><div class="gp">%s Decks</div><div class="ttl"><b>Flipside</b><span>%d slides · 4:30 · edited just now</span></div><div class="row"><div class="pr">Present</div><div class="more">%s</div></div></div>'
           % (t, status_icons(C["paper"]), t, svg(ICON["chev_l"], 18, C["paper"], 2.2), n, svg(ICON["dots"], 18, C["paper"])))
    notes_card = '<div class="ta"><div class="lbl" style="margin-bottom:8px">Notes</div>%s<i class="caret"></i></div>' % s["notes"]
    editor_chrome = ('<div class="edh" style="opacity:%s"><div><div class="lbl">Slide %d · %s</div><b>Notes &amp; cue</b></div><div class="chip">%s %s</div></div>'
                     % (chrome_op, sel, s["title"], svg(ICON["clock"], 14, C["ash"], 2), hint))
    if s["cue"]:
        cue = ('<div style="opacity:%s"><div class="lbl" style="margin:14px 0 6px">Cue to advance</div><div class="cuef">%s<b>“%s”</b><span>Test</span></div></div>'
               % (chrome_op, svg(ICON["mic"], 18, C["verdl"], 2), s["cue"]))
    else:
        cue = ('<div style="opacity:%s"><div class="lbl" style="margin:14px 0 6px">Cue to advance</div><div class="cuef">%s<b style="color:var(--ash);font-weight:500">No cue · closing the phone ends the talk</b></div></div>'
               % (chrome_op, svg(ICON["mic"], 18, C["ash"], 2)))
    tb = ('<div class="tb" style="opacity:%s"><div class="g"><div class="k">%s</div><div class="k">%s</div><div class="k">%s Dictate</div></div><div class="done">Done</div></div>'
          % (chrome_op, svg(ICON["textfmt"], 18, C["paper"]), svg(ICON["list"], 18, C["paper"]), svg(ICON["mic"], 18, C["paper"])))
    if t >= 1:
        ed = '<div class="ed">%s%s%s</div>%s<div class="hi"></div>' % (editor_chrome, notes_card, cue, tb)
        fly = ""
    else:
        # transition: notes card travels from the presenter card (20,72,416x371) to the editor card (20,548,629x192); slide flies to its slot
        e = 1 - (1 - t) ** 3.2
        x = 20; y = 72 + (548 - 72) * e; w = 416 + (629 - 416) * e; h = 371 + (192 - 371) * e
        ed = ('<div class="ed">%s%s</div>%s'
              '<div class="abs" style="left:%spx;top:%spx;width:%spx;height:%spx"><div class="ta" style="margin:0;height:100%%">%s%s<i class="caret" style="opacity:%s"></i></div></div>'
              % (editor_chrome, '<div style="height:206px"></div>' + cue, tb, x, round(y, 1), round(w, 1), round(h, 1),
                 '<div class="lbl" style="margin-bottom:8px">Notes</div>', s["notes"], chrome_op))
        e2 = 1 - (1 - t) ** 2.5
        sx0, sy0, sw0 = 16, 475.5 + 30, 637
        sx1, sy1, sw1 = 34.5 + pos[sel][0], 116 + pos[sel][1], 192
        sx = sx0 + (sx1 - sx0) * e2; sy = sy0 + (sy1 - sy0) * e2; sw = sw0 + (sw1 - sw0) * e2
        fly = '<div class="abs" style="left:%spx;top:%spx;filter:drop-shadow(0 16px 30px rgba(0,0,0,.55))">%s</div>' % (round(sx, 1), round(sy, 1), slidebox(sel, round(sw, 1), 8))
    return '<div class="edit">%s%s%s%s</div>' % (top, grid, ed, fly)

def transition_screen(t):
    """t in (0,1): presenter chrome fades, notes card and slide in flight, edit chrome fades in."""
    pres = presenter_half(3)
    # the presenter layer without its notes card (the card is drawn in flight by edit_screen)
    fade = max(0.0, 1 - t * 1.7)
    return ('<div class="screen" style="width:669px;height:951px;position:relative;overflow:hidden;background:var(--ink)">'
            '<div class="abs" style="left:0;top:0;opacity:%s;transform:scale(%s);transform-origin:50%% 0">%s</div>'
            '<div class="abs" style="left:0;top:0">%s</div></div>'
            % (round(fade, 3), round(1 - 0.05 * t, 3), pres.replace('<div class="notes">', '<div class="notes" style="visibility:hidden">'), edit_screen(3, 6, t)))

# ---------------------------------------------------------------- ended state (outer display 466 x 678) and recap mail
ENDED_CSS = """
.ended{width:466px;height:678px;background:var(--ink);color:var(--paper);position:relative;overflow:hidden;font-family:var(--sans)}
.ended .cam{position:absolute;right:14px;top:14px;width:24px;height:24px;border-radius:50%;background:#000;box-shadow:0 0 0 1px rgba(241,242,244,.08),inset 0 0 0 5px #05070a}
.ended .time{position:absolute;left:22px;top:16px;font:600 15px/1 var(--sans);font-variant-numeric:tabular-nums}
.ended .ctr{position:absolute;left:40px;right:64px;top:112px;display:flex;flex-direction:column;align-items:flex-start;gap:14px}
.ended .ck{width:64px;height:64px;border-radius:50%;background:rgba(70,169,143,.16);display:flex;align-items:center;justify-content:center;margin-bottom:8px}
.ended h1{font:600 30px/34px var(--sans);letter-spacing:-.01em}
.ended .sub{font:400 17px/23px var(--sans);color:var(--ash)}
.ended .card{margin-top:8px;width:100%;background:var(--slate);border-radius:14px;padding:14px 16px}
.ended .card b{display:block;font:600 15px/20px var(--sans)}
.ended .card span{display:block;font:400 13px/18px var(--sans);color:var(--ash);margin-top:3px}
.ended .btns{position:absolute;left:40px;right:64px;bottom:64px;display:flex;flex-direction:column;gap:10px}
.ended .b1{height:50px;border-radius:14px;background:var(--verdl);color:var(--ink);font:600 17px/50px var(--sans);text-align:center}
.ended .b2{height:50px;border-radius:14px;background:var(--slate);color:var(--paper);font:500 17px/50px var(--sans);text-align:center;font-variant-numeric:tabular-nums}
.ended .foot{position:absolute;left:40px;bottom:26px;display:flex;align-items:center;gap:8px;font:400 12px/1 var(--sans);color:var(--ash)}
.ended .side{position:absolute;right:0;top:0;bottom:0;width:52px;display:flex;flex-direction:column;align-items:center;gap:14px;padding-top:50px}
"""

def ended_screen():
    return ('<div class="ended"><div class="cam"></div><div class="time">10:21</div>'
            '<div class="ctr" style="top:132px"><div class="ck">%s</div><h1>Meeting ended</h1><div class="sub">Recap sent to 4 people</div>'
            '<div class="card"><b>Recap: Flipside with Kartik</b><span>To Priya, Jonas, Amara, Lee</span><span>9 slides · 6 min · 10:15–10:21</span></div></div>'
            '<div class="btns" style="bottom:88px"><div class="b1">Open recap</div><div class="b2">Undo send · 0:27</div></div>'
            '<div class="foot" style="bottom:34px">%s Closed the phone, so the talk is over.</div></div>'
            % (svg(ICON["check"], 30, C["verdl"], 2.6), mark(14, True)))

MAIL_CSS = """
.mail{background:#fff;color:#000;position:relative;overflow:hidden;font-family:var(--sans)}
.mail .sb{position:absolute;left:0;right:0;top:0;height:54px;display:flex;align-items:center;justify-content:space-between;padding:0 30px 0 34px;font:600 16px/1 var(--sans);font-variant-numeric:tabular-nums}
.mail .di{position:absolute;left:50%;top:11px;width:124px;height:36px;margin-left:-62px;border-radius:20px;background:#000}
.mail .nb{position:absolute;left:8px;right:16px;top:56px;height:44px;display:flex;align-items:center;justify-content:space-between;color:#007AFF;font:400 17px/1 var(--sans)}
.mail .nb .bk{display:flex;align-items:center;gap:2px}
.mail .bd{position:absolute;left:0;right:0;overflow:hidden;padding:0 20px}
.mail h1{font:600 22px/27px var(--sans);letter-spacing:-.01em;color:#000;margin-top:8px}
.mail .frm{display:flex;align-items:center;gap:12px;margin-top:16px;padding-bottom:14px;border-bottom:1px solid rgba(60,60,67,.18)}
.mail .av{width:40px;height:40px;border-radius:50%;background:var(--verd);display:flex;align-items:center;justify-content:center;flex:none}
.mail .frm b{display:block;font:600 16px/20px var(--sans)}
.mail .frm span{display:block;font:400 13px/17px var(--sans);color:rgba(60,60,67,.6)}
.mail .frm .tm{margin-left:auto;font:400 15px/1 var(--sans);color:rgba(60,60,67,.6);align-self:flex-start;margin-top:2px}
.mail p{font:400 17px/24px var(--sans);color:#000;margin-top:14px}
.mail a{color:var(--verd);text-decoration:underline;text-underline-offset:2px}
.mail .prev{margin-top:16px;border:1px solid rgba(60,60,67,.18);border-radius:14px;overflow:hidden}
.mail .prev .pc{padding:10px 14px;display:flex;align-items:center;justify-content:space-between;background:#F7F7F8}
.mail .prev .pc b{display:block;font:600 14px/18px var(--sans)}
.mail .prev .pc span{display:block;font:400 12px/16px var(--sans);color:rgba(60,60,67,.6)}
.mail .sig{display:flex;align-items:center;gap:8px;margin-top:18px;font:400 13px/1 var(--sans);color:rgba(60,60,67,.6)}
.mail .tb{position:absolute;left:0;right:0;bottom:0;height:84px;border-top:1px solid rgba(60,60,67,.18);background:rgba(249,249,249,.94);display:flex;align-items:flex-start;justify-content:space-around;padding:14px 12px 0;color:#007AFF}
.mail .hi{position:absolute;left:50%;bottom:8px;width:140px;height:5px;margin-left:-70px;border-radius:3px;background:#000}
"""

def recap_body(first="Priya"):
    return ('<p>Hi %s,</p>'
            '<p>Kartik just presented “Flipside” from Flipside. It ran 9 slides in 6 minutes.</p>'
            '<p>The short version: When the phone closes, the talk is over and a five-line recap is already in your inbox.</p>'
            '<p>Questions raised: none</p>'
            '<p>Slides and notes are here: <a>flipside.app/r/8k2m</a></p>'
            '<div class="prev">%s<div class="pc"><div><b>Flipside · slides and notes</b><span>flipside.app · 9 slides · 6 min</span></div>%s</div></div>'
            '<div class="sig">%s Sent by Flipside when the phone closed.</div>' % (first, slidebox(1, 360, 0, False, "width:100%;height:auto;aspect-ratio:1200/630"), svg(ICON["chev_r"], 16, "rgba(60,60,67,.4)", 2), mark(14)))

def mail_iphone():
    return ('<div class="mail" style="width:402px;height:874px"><div class="sb"><span>10:22</span>%s</div><div class="di"></div>'
            '<div class="nb"><div class="bk">%s Inbox</div><div class="row" style="gap:18px">%s%s</div></div>'
            '<div class="bd" style="top:104px;bottom:84px"><h1>Recap: Flipside with Kartik</h1>'
            '<div class="frm"><div class="av">%s</div><div><b>Flipside</b><span>on behalf of Kartik Kapoor · to Priya Nair</span></div><div class="tm">10:21</div></div>%s</div>'
            '<div class="tb">%s%s%s%s</div><div class="hi"></div></div>'
            % (status_icons("#000"), svg(ICON["chev_l"], 22, "#007AFF", 2.4), svg(ICON["up"], 20, "#007AFF", 2.2), svg(ICON["down"], 20, "#007AFF", 2.2),
               mark(20, True), recap_body("Priya"), svg(ICON["archive"], 24, "#007AFF", 1.7), svg(ICON["trash"], 24, "#007AFF", 1.7), svg(ICON["reply"], 24, "#007AFF", 1.7), svg(ICON["compose"], 24, "#007AFF", 1.7)))

def mail_duo_outer():
    # Same mail on the Duo's outer display (466 x 678): controls on the trailing side, camera in the corner.
    return ('<div class="mail" style="width:466px;height:678px"><div class="abs" style="right:14px;top:14px;width:24px;height:24px;border-radius:50%%;background:#000"></div>'
            '<div class="abs" style="left:22px;top:16px;font:600 15px/1 var(--sans);font-variant-numeric:tabular-nums">10:22</div>'
            '<div class="abs" style="right:0;top:52px;bottom:0;width:52px;display:flex;flex-direction:column;align-items:center;gap:22px;padding-top:10px;color:#007AFF">%s<div style="height:6px"></div>%s%s%s%s</div>'
            '<div class="bd" style="top:48px;bottom:0;right:52px;padding-right:12px"><h1 style="font-size:20px;line-height:24px">Recap: Flipside with Kartik</h1>'
            '<div class="frm"><div class="av">%s</div><div><b>Flipside</b><span>on behalf of Kartik Kapoor · to Priya Nair</span></div><div class="tm">10:21</div></div>%s</div></div>'
            % (svg(ICON["chev_l"], 22, "#007AFF", 2.4), svg(ICON["archive"], 22, "#007AFF", 1.7), svg(ICON["trash"], 22, "#007AFF", 1.7), svg(ICON["reply"], 22, "#007AFF", 1.7), svg(ICON["compose"], 22, "#007AFF", 1.7),
               mark(20, True), recap_body("Priya")))

# ---------------------------------------------------------------- device frames (2D, in points; scale with .zoom wrapper)
FRAME_CSS = """
.dev{position:relative;background:linear-gradient(160deg,#4a4d55 0%,#2b2e34 45%,#1c1e23 100%);box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.14),inset 0 0 0 4px #0b0c0e,0 40px 80px rgba(0,0,0,.55),0 10px 24px rgba(0,0,0,.4)}
.dev .scr{position:absolute;overflow:hidden;background:#000}
.dev .btn{position:absolute;background:linear-gradient(90deg,#3a3d44,#23262b);border-radius:2px}
.dev .seam{position:absolute;left:0;right:0;height:1px;background:rgba(0,0,0,.35)}
"""

def frame(kind, inner, scale=1.0, shadow=True, style=""):
    if kind == "duo-open":      # unfolded, portrait: body 710 x 993, screen 669 x 951, hinge horizontal
        W, H, sw, sh, sx, sy, rb, rs = 710, 993, 669, 951, 20.5, 21, 56, 38
        extra = ('<div class="btn" style="right:-3px;top:170px;width:3px;height:64px"></div><div class="btn" style="left:-3px;top:150px;width:3px;height:34px"></div><div class="btn" style="left:-3px;top:196px;width:3px;height:60px"></div>'
                 '<div class="seam" style="top:496px;left:0;width:20px"></div><div class="seam" style="top:496px;right:0;left:auto;width:20px"></div>')
    elif kind == "duo-closed":  # closed: body 508 x 711, outer screen 466 x 678
        W, H, sw, sh, sx, sy, rb, rs = 508, 711, 466, 678, 21, 16.5, 52, 36
        extra = ('<div class="btn" style="right:-3px;top:150px;width:3px;height:64px"></div>'
                 '<div class="abs" style="left:0;top:0;bottom:0;width:9px;border-radius:52px 0 0 52px;background:linear-gradient(90deg,rgba(0,0,0,.35),rgba(0,0,0,0))"></div>')
    elif kind == "iphone":      # iPhone 17: body 432 x 904, screen 402 x 874
        W, H, sw, sh, sx, sy, rb, rs = 432, 904, 402, 874, 15, 15, 62, 52
        extra = '<div class="btn" style="right:-3px;top:200px;width:3px;height:80px"></div><div class="btn" style="left:-3px;top:150px;width:3px;height:28px"></div><div class="btn" style="left:-3px;top:196px;width:3px;height:56px"></div><div class="btn" style="left:-3px;top:262px;width:3px;height:56px"></div>'
    else:
        raise ValueError(kind)
    sh_css = "" if shadow else "box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.14),inset 0 0 0 4px #0b0c0e;"
    return ('<div style="width:%spx;height:%spx;%s"><div class="dev" style="width:%spx;height:%spx;border-radius:%spx;transform:scale(%s);transform-origin:0 0;%s">'
            '<div class="scr" style="left:%spx;top:%spx;width:%spx;height:%spx;border-radius:%spx">%s</div>%s</div></div>'
            % (W*scale, H*scale, style, W, H, rb, scale, sh_css, sx, sy, sw, sh, rs, inner, extra))

# ---------------------------------------------------------------- 3D folded phone scene (CSS transforms)
SCENE_CSS = """
.stage{position:absolute;perspective:2600px;perspective-origin:50% 42%}
.world{position:absolute;left:50%;top:50%;transform-style:preserve-3d}
.tbl{position:absolute;left:-2400px;top:-2400px;width:4800px;height:4800px;background:radial-gradient(ellipse at 50% 50%,rgba(255,255,255,.045),rgba(255,255,255,0) 55%)}
.shadow{position:absolute;left:-560px;top:-330px;width:1120px;height:660px;border-radius:50%;background:radial-gradient(ellipse at 50% 50%,rgba(0,0,0,.62),rgba(0,0,0,0) 62%)}
.half{position:absolute;width:589px;height:411.5px;transform-style:preserve-3d}
.half .face{position:absolute;inset:0;background:linear-gradient(160deg,#454850,#25282e 60%,#1b1d22);backface-visibility:hidden;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.12)}
.half .scr{position:absolute;left:17px;width:554.5px;height:394.5px;overflow:hidden;background:#000}
.half .back{position:absolute;inset:0;background:linear-gradient(20deg,#1d1f24,#33363d 55%,#25282e);backface-visibility:hidden;transform:rotateY(180deg) translateZ(26px);box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.08)}
.half .wall{position:absolute;background:#202329}
"""

def half3d(inner_html, far=True, phi=45.0, radius=46):
    # far half: origin at its bottom edge (hinge); near half: origin at its top edge (hinge). Face normal starts +Z; laid on the table by rotateX(90 ∓ phi).
    if far:
        pos = "left:-294.5px;top:-411.5px;transform-origin:50%% 100%%;transform:rotateX(%sdeg)" % (90 - phi)
        scr_top = 17; rad = "%spx %spx 0 0" % (radius, radius)
        walls = ('<div class="wall" style="left:0;top:0;width:589px;height:26px;transform-origin:top;transform:rotateX(-90deg)"></div>'
                 '<div class="wall" style="left:0;top:0;width:26px;height:411.5px;transform-origin:left;transform:rotateY(90deg)"></div>'
                 '<div class="wall" style="right:0;top:0;width:26px;height:411.5px;transform-origin:right;transform:rotateY(-90deg)"></div>')
    else:
        pos = "left:-294.5px;top:0;transform-origin:50%% 0;transform:rotateX(%sdeg)" % (90 + phi)
        scr_top = 0; rad = "0 0 %spx %spx" % (radius, radius)
        walls = ('<div class="wall" style="left:0;bottom:0;width:589px;height:26px;transform-origin:bottom;transform:rotateX(90deg)"></div>'
                 '<div class="wall" style="left:0;top:0;width:26px;height:411.5px;transform-origin:left;transform:rotateY(90deg)"></div>'
                 '<div class="wall" style="right:0;top:0;width:26px;height:411.5px;transform-origin:right;transform:rotateY(-90deg)"></div>')
    return ('<div class="half" style="%s"><div class="face" style="border-radius:%s"><div class="scr" style="top:%spx;border-radius:%s"><div style="width:669px;height:475.5px;transform:scale(0.8288);transform-origin:0 0">%s</div></div></div>'
            '<div class="back" style="border-radius:%s"></div>%s</div>' % (pos, rad, scr_top, rad, inner_html, rad, walls))

def scene3d(theta, top_html, bottom_html, left, top, width, height, elev=50, az=18, zoom=1.35, shift_y=0):
    """theta = hinge angle in degrees (180 flat). top_html = far half (display top half, upright), bottom_html = near half (display bottom half, as drawn)."""
    phi = (180 - theta) / 2.0
    return ('<div class="stage" style="left:%spx;top:%spx;width:%spx;height:%spx"><div class="world" style="transform:translateY(%spx) scale3d(%s,%s,%s) rotateX(%sdeg) rotateY(%sdeg)">'
            '<div class="tbl" style="transform:translateY(26px) rotateX(90deg)"></div>'
            '<div class="shadow" style="transform:translateY(25px) rotateX(90deg)"></div>%s%s</div></div>'
            % (left, top, width, height, shift_y, zoom, zoom, zoom, -elev, az, half3d(top_html, True, phi), half3d(bottom_html, False, phi)))

# ---------------------------------------------------------------- page + render
def _rgb(hexcol):
    h = hexcol.lstrip("#"); return "%d,%d,%d" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def page(body, css="", w=None, h=None, bg="transparent"):
    size = "width:%spx;height:%spx;overflow:hidden;" % (w, h) if w else ""
    html = ('<!doctype html><html><head><meta charset="utf-8"><title>Flipside</title><style>%s%s%s%s%s%s%s%s%s%s%s</style></head><body style="%sbackground:%s">%s</body></html>'
            % (BASE_CSS, SLIDE_CSS, PRES_CSS, AUD_CSS, EDIT_CSS, ENDED_CSS, MAIL_CSS, FRAME_CSS, SCENE_CSS, MOCK_CSS, css, size, bg, body))
    # the dark-theme accent is written literally in the mockup chrome; keep it in step with tokens.json
    return html.replace("#46A98F", C["verdl"]).replace("70,169,143", _rgb(C["verdl"]))

MOCK_CSS = """
.mock{width:2400px;height:1600px;position:relative;overflow:hidden;background:radial-gradient(ellipse at 50% 38%,#25262a 0%,#1a1b1e 55%,#151618 100%);color:#F1F2F4;font-family:var(--sans)}
.mock .hd{position:absolute;left:80px;top:56px;display:flex;align-items:center;gap:22px}
.mock .hd .no{font:400 40px/1 var(--serif);color:#F1F2F4;opacity:.55}
.mock .hd h1{font:400 40px/1 var(--serif);letter-spacing:-.01em;color:#F1F2F4}
.mock .hd .sub{font:400 17px/1 var(--sans);color:#9AA3AE;margin-top:8px}
.mock .brand{position:absolute;right:80px;top:56px}
.mock .ft{position:absolute;left:80px;right:80px;bottom:44px;display:flex;justify-content:space-between;font:400 15px/1.5 var(--sans);color:#7f8894}
.mock .tag{display:inline-flex;align-items:center;gap:10px;height:34px;padding:0 14px;border-radius:17px;font:600 13px/1 var(--sans);letter-spacing:.06em;text-transform:uppercase}
.mock .tag.a{background:rgba(70,169,143,.16);color:#46A98F}
.mock .tag.p{background:rgba(241,242,244,.1);color:#F1F2F4}
.mock .tag.n{background:rgba(241,242,244,.06);color:#9AA3AE}
.mock .cap{font:400 16px/24px var(--sans);color:#9AA3AE}
.mock .cap b{color:#F1F2F4;font-weight:600}
.mock .callout{position:absolute;display:flex;gap:14px;align-items:flex-start;width:520px}
.mock .callout .n{width:30px;height:30px;border-radius:50%;background:#46A98F;color:#111418;font:600 14px/30px var(--sans);text-align:center;flex:none}
.mock .callout b{display:block;font:600 17px/22px var(--sans);color:#F1F2F4}
.mock .callout span{display:block;font:400 15px/21px var(--sans);color:#9AA3AE;margin-top:3px}
.mock .lead{position:absolute;height:1px;background:rgba(70,169,143,.7);transform-origin:0 50%}
.mock .lead:after{content:"";position:absolute;right:-4px;top:-4px;width:8px;height:8px;border-radius:50%;background:#46A98F}
.mock .shot{filter:drop-shadow(0 30px 60px rgba(0,0,0,.55))}
.mock .angle{position:absolute;font:400 120px/1 var(--serif);color:#F1F2F4;letter-spacing:-.02em}
.mock .angle small{font:400 22px/1 var(--sans);color:#9AA3AE;margin-left:14px;letter-spacing:0}
"""

def write_html(name, html):
    HTML_DIR.mkdir(parents=True, exist_ok=True)
    p = HTML_DIR / (name + ".html")
    p.write_text(html)
    return p

def shot(html_path, out_png, w, h, dpr=1, timeout=120):
    out_png = Path(out_png); out_png.parent.mkdir(parents=True, exist_ok=True)
    prof = Path("/private/tmp/claude-501/-Users-kartik/c9a48104-fb38-46ad-819a-d7066c467214/scratchpad/chrome-profiles") / uuid.uuid4().hex
    prof.mkdir(parents=True, exist_ok=True)
    tmp = out_png.with_suffix(".tmp.png")
    if tmp.exists(): tmp.unlink()
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files", "--no-first-run", "--no-default-browser-check",
           "--disable-extensions", "--disable-sync", "--user-data-dir=%s" % prof, "--force-device-scale-factor=%s" % dpr, "--window-size=%s,%s" % (w, h),
           "--virtual-time-budget=2500", "--run-all-compositor-stages-before-draw", "--screenshot=%s" % tmp, "file://%s" % html_path]
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t0 = time.time()
        while time.time() - t0 < timeout:
            if p.poll() is not None: break
            if tmp.exists() and tmp.stat().st_size > 0:
                time.sleep(0.6)
                if p.poll() is None: p.kill()
                break
            time.sleep(0.25)
        else:
            p.kill()
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    if not tmp.exists():
        raise RuntimeError("no screenshot for %s" % html_path)
    os.replace(tmp, out_png)
    return out_png

def png_size(p):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(p)], capture_output=True, text=True).stdout
    vals = [int(l.split(":")[-1]) for l in out.splitlines() if "pixel" in l]
    return tuple(vals)
