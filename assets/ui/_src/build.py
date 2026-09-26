# Flipside UI mockups — builds every deliverable in ~/flipside-assets/ui
#   python3 build.py            -> everything (raw screens @3x, mockups 01-06, contact sheet, SUMMARY.md)
#   python3 build.py 03 05      -> only the named mockups (substring match)
#   python3 build.py raw        -> raw screens only
import sys, math, shutil, json, time, datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent.parent
# Snapshot the moving inputs first, so one build uses one deck and one palette.
if "--nosnap" not in sys.argv:
    shutil.copy(ASSETS / "deck" / "deck.json", HERE / "deck-snapshot.json")
    shutil.copy(ASSETS / "brand" / "tokens.json", HERE / "tokens-snapshot.json")
sys.argv = [a for a in sys.argv if a != "--nosnap"]

from common import *
import raw_screens

OUT = UI
DATE = "26 Sep 2026"
SPEC = "iPhone Duo inner display 669 × 951 pt @3x (2007 × 2853 px) · hinge horizontal at 475.5 pt · each half 669 × 475.5 pt"

def header(no, title, sub):
    return ('<div class="hd"><div class="no">%s</div><div><h1>%s</h1><div class="sub">%s</div></div></div><div class="brand">%s</div>'
            % (no, title, sub, wordmark(30, True)))

def footer(left, right="Flipside · UI mockups · %s" % DATE):
    return '<div class="ft"><div>%s</div><div>%s</div></div>' % (left, right)

def half_panel(inner, x, y, scale, corners, label_html, fold_side):
    """A screen half at scale with display-corner rounding; fold edge marked."""
    w, h = 669 * scale, 475.5 * scale
    fold = ('<div class="abs" style="left:0;right:0;%s:-30px;height:1px;border-top:1.5px dashed rgba(70,169,143,.55)"></div>'
            '<div class="abs" style="%s:-46px;left:50%%;transform:translateX(-50%%);font:600 11px/1 var(--sans);letter-spacing:.1em;color:#46A98F">FOLD · 475.5 PT</div>') % (fold_side, fold_side)
    return ('<div class="abs" style="left:%spx;top:%spx">%s<div class="shot" style="width:%spx;height:%spx;border-radius:%s;overflow:hidden;position:relative">'
            '<div style="transform:scale(%s);transform-origin:0 0">%s</div></div>%s</div>'
            % (x, y, label_html, w, h, corners, scale, inner, fold))

def vsec_svg(w=520, h=300, theta=90):
    """Side view of the V standing on its hinge. You are on the right; each viewer sees the far leg."""
    cx, cy, L = w/2, h-60, 150
    a = math.radians(theta/2)
    lx, ly = cx - L*math.sin(a), cy - L*math.cos(a)      # far leg from you = presenter half (faces you)
    rx, ry = cx + L*math.sin(a), cy - L*math.cos(a)      # near leg = audience half (faces them)
    mlx, mly = cx - 0.55*L*math.sin(a), cy - 0.55*L*math.cos(a)
    mrx, mry = cx + 0.55*L*math.sin(a), cy - 0.55*L*math.cos(a)
    F = 'font-family="-apple-system,system-ui"'
    return ('<svg width="%s" height="%s" viewBox="0 0 %s %s" style="display:block">'
            '<line x1="20" y1="%s" x2="%s" y2="%s" stroke="rgba(241,242,244,.18)" stroke-width="2"/>'
            '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#F1F2F4" stroke-width="12" stroke-linecap="round"/>'
            '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#46A98F" stroke-width="12" stroke-linecap="round"/>'
            '<text x="%s" y="%s" fill="#9AA3AE" %s font-size="14" text-anchor="end">presenter half</text>'
            '<text x="%s" y="%s" fill="#46A98F" %s font-size="14" text-anchor="start">audience half</text>'
            '<text x="34" y="%s" fill="#F1F2F4" %s font-size="16" font-weight="600" text-anchor="middle">them</text>'
            '<text x="%s" y="%s" fill="#F1F2F4" %s font-size="16" font-weight="600" text-anchor="middle">you</text>'
            '<path d="M58 %s C 140 %s, %s %s, %s %s" fill="none" stroke="rgba(241,242,244,.35)" stroke-width="1.5" stroke-dasharray="4 5"/>'
            '<path d="M%s %s C %s %s, %s %s, %s %s" fill="none" stroke="rgba(241,242,244,.35)" stroke-width="1.5" stroke-dasharray="4 5"/>'
            '<text x="%s" y="%s" fill="#9AA3AE" %s font-size="13" text-anchor="middle">each of you sees the far half · hinge on the table · %s°</text></svg>'
            % (w, h, w, h, cy+8, w-20, cy+8,
               cx, cy, lx, ly, cx, cy, rx, ry,
               mlx-14, mly+5, F, mrx+14, mry+5, F,
               cy-124, F, w-34, cy-124, F,
               cy-114, cy-150, rx-40, ry-40, rx-6, ry-6,
               w-58, cy-114, w-140, cy-150, lx+40, ly-40, lx+6, ly-6,
               cx, h-12, F, theta))

# ---------------------------------------------------------------- 01 present mode
def mock_01():
    s = 1.55
    pres = presenter_half(3)
    aud = audience_half(3)
    aud_rot = '<div style="width:669px;height:475.5px;transform:rotate(180deg)">%s</div>' % aud
    left_lbl = ('<div class="row" style="gap:14px;position:absolute;top:-72px;left:0"><span class="tag p">Presenter half · faces you</span><span class="cap">top half of the display · upright</span></div>')
    right_lbl = ('<div class="row" style="gap:14px;position:absolute;top:-104px;left:0"><span class="tag a">Audience half · faces the room</span><span class="cap">bottom half · drawn rotated 180°</span></div>')
    body = (header("01", "Present mode", "Both halves of the inner display, exactly as the app draws them at a 90° hinge") +
            half_panel(pres, 80, 330, s, "38px 38px 6px 6px", left_lbl, "bottom") +
            half_panel(aud_rot, 1283, 330, s, "6px 6px 38px 38px", right_lbl, "top") +
            '<div class="abs" style="left:80px;top:1120px">%s</div>' % vsec_svg(520, 300, 90) +
            '<div class="abs" style="left:640px;top:1130px;width:560px" class="cap"><div class="cap"><b>Why the rotation.</b> The phone stands on its hinge as a V. You see the far half upright. The near half faces the room and its natural "up" points at the table, so the slide is drawn upside down and mirrored, i.e. rotated 180°, and reads correctly from across the table.</div>'
            '<div class="cap" style="margin-top:16px"><b>Fold gutter.</b> Nothing sits within 16 pt of the hinge on either side; the real inset comes from <code style="font:500 14px ui-monospace,Menlo;color:#F1F2F4">ReservedRegion(kind: .division)</code>.</div></div>' +
            '<div class="abs" style="left:1283px;top:1112px"><div class="row" style="gap:12px;margin-bottom:12px"><span class="tag n">What the audience sees</span><span class="cap">same half, un-rotated</span></div>'
            '<div class="shot" style="width:%spx;height:%spx;border-radius:22px;overflow:hidden;position:relative"><div style="transform:scale(.62);transform-origin:0 0">%s</div></div></div>' % (669*.62, 475.5*.62, audience_half(3)) +
            '<div class="abs" style="left:1740px;top:1112px;width:580px"><div class="cap"><b>Presenter half.</b> Slide n of N, elapsed clock and per-slide time, prev/next, End; notes; the cue phrase the mic is listening for; next slide; laser trackpad (197 × 217 pt).</div>'
            '<div class="cap" style="margin-top:16px"><b>Audience half.</b> The slide at 637 × 334 pt (1200 × 630 canvas), deck progress near the hinge where the near half hides it from nobody who matters.</div></div>' +
            footer(SPEC))
    return page('<div class="mock">%s</div>' % body, w=2400, h=1600, bg="#1a1b1e")

# ---------------------------------------------------------------- 02 edit mode
def mock_02():
    s = 1.22
    px, py = 130, 190                          # frame origin
    ox, oy = px + 20.5*s, py + 21*s            # screen origin in page px
    def P(x, y): return (ox + x*s, oy + y*s)
    targets = [
        ("Deck grid", "Three columns, whole deck in view. Selected slide gets the accent outline.", P(560, 160)),
        ("Reorder", "Long-press lifts a tile; the accent bar shows where it drops.", P(300, 275)),
        ("Present", "Enters present mode. Folding to about 90° does the same thing.", P(600, 78)),
        ("The fold", "475.5 pt. The editor lives below it, so a half-open phone still reads.", P(669, 475.5)),
        ("Notes", "Editable; the same text the presenter half shows at 17/26 pt.", P(560, 620)),
        ("Cue to advance", "The phrase the mic listens for. Test plays it back through the recogniser.", P(560, 805)),
        ("Time hint", "durationHint per slide; feeds the per-slide clock.", P(612, 522)),
    ]
    callouts, lines = [], []
    cy0 = 250
    for i, (t, d, (tx, ty)) in enumerate(targets):
        cy = cy0 + i*168
        callouts.append('<div class="callout" style="left:1320px;top:%spx"><div class="n">%d</div><div><b>%s</b><span>%s</span></div></div>' % (cy, i+1, t, d))
        lines.append('<path d="M1312 %s L1010 %s L%s %s" fill="none" stroke="rgba(70,169,143,.7)" stroke-width="1.5"/><circle cx="%s" cy="%s" r="6" fill="#46A98F"/><circle cx="%s" cy="%s" r="12" fill="rgba(70,169,143,.25)"/>'
                     % (cy+15, cy+15, tx, ty, tx, ty, tx, ty))
    body = (header("02", "Edit mode", "Flat on the table (180°). Reorderable deck grid on the far half, notes and cue editor on the near half") +
            '<div class="abs shot" style="left:%spx;top:%spx">%s</div>' % (px, py, frame("duo-open", edit_screen(3, 6, 1.0), s)) +
            '<svg class="abs" style="left:0;top:0" width="2400" height="1600">%s</svg>' % "".join(lines) +
            "".join(callouts) +
            '<div class="abs" style="left:1320px;top:1445px;width:900px" class="cap"><div class="cap">Keyboard not drawn: it covers the bottom ~310 pt when the notes field is active; the editor scrolls. Grid rows never straddle the fold, so folding to tabletop keeps every tile whole.</div></div>' +
            footer(SPEC))
    return page('<div class="mock">%s</div>' % body, w=2400, h=1600, bg="#1a1b1e")

# ---------------------------------------------------------------- 03 transition frames (3D)
STAGE_BASE = dict(left=60, top=110, width=1560, height=1420, elev=52, az=16, zoom=1.42, shift_y=40)
STAGE = dict(STAGE_BASE)

def stage_for(theta):
    st = dict(STAGE_BASE)
    if theta >= 180: st.update(zoom=1.16, shift_y=-70)
    elif theta > 110: st.update(zoom=1.28, shift_y=-10)
    return st

def project(p, theta, far):
    STAGE = stage_for(theta)
    """Page coords of a point given in a half's local frame (x right, y from the hinge edge, z=0)."""
    phi = (180 - theta) / 2.0
    x, yl = p
    if far:
        a = math.radians(90 - phi); y0 = -yl
    else:
        a = math.radians(90 + phi); y0 = yl
    # rotateX(a): (x, y cos a − z sin a, y sin a + z cos a), z = 0
    X, Y, Z = x, y0*math.cos(a), y0*math.sin(a)
    b = math.radians(STAGE["az"])
    X, Z = X*math.cos(b) + Z*math.sin(b), -X*math.sin(b) + Z*math.cos(b)
    e = math.radians(-STAGE["elev"])
    Y, Z = Y*math.cos(e) - Z*math.sin(e), Y*math.sin(e) + Z*math.cos(e)
    z = STAGE["zoom"]; X, Y, Z = X*z, Y*z, Z*z
    Y += STAGE["shift_y"]
    d = 2600.0
    oy = -0.08 * STAGE["height"]
    k = d / (d - Z)
    px = X * k
    py = oy + (Y - oy) * k
    return (STAGE["left"] + STAGE["width"]/2 + px, STAGE["top"] + STAGE["height"]/2 + py)

def mock_03(theta):
    if theta <= 110:
        top, bot, rot = presenter_half(3), audience_half(3), 180
        sub = "Present. The phone stands on its hinge; you see the far half, the room sees the near half"
        lab_far = ("Presenter half (far)", "faces you · upright")
        lab_near = ("Audience half (near)", "faces the room · drawn upside down")
        note = ("<b>90° is the working pose.</b> Notes, cue, clock and the laser pad face you on the far half. The slide faces the room on the near half, rotated 180°. "
                "Everything inside 16 pt of the hinge stays empty.")
        raw = present_screen(3)
    elif theta < 180:
        t = (theta - 110) / 50.0
        full = transition_screen(t)
        top = '<div style="width:669px;height:951px;overflow:hidden">%s</div>' % full
        bot = '<div style="width:669px;height:475.5px;overflow:hidden"><div style="margin-top:-475.5px">%s</div></div>' % full
        rot = 0
        sub = "Opening. Past 110° the near half un-rotates and the layout starts to swap"
        lab_far = ("Far half", "grid fading in · slide flying to its slot")
        lab_near = ("Near half", "notes card sliding under the fold · now upright")
        note = ("<b>t = %.2f at %d°.</b> Nobody across the table can see the near half past 110°, so it flips upright. The notes card leaves the presenter panel, "
                "crosses under the fold and grows into the editor. The current slide shrinks up into its grid slot; the other tiles fade in around it. Reverse the same path when folding back.") % (t, theta)
        raw = full
    else:
        full = edit_screen(3, 6, 1.0)
        top = '<div style="width:669px;height:951px;overflow:hidden">%s</div>' % full
        bot = '<div style="width:669px;height:475.5px;overflow:hidden"><div style="margin-top:-475.5px">%s</div></div>' % full
        rot = 0
        sub = "Flat. Edit mode: deck grid on the far half, notes and cue editor on the near half"
        lab_far = ("Far half", "deck grid")
        lab_near = ("Near half", "notes + cue editor")
        note = ("<b>180° is edit mode.</b> The far half holds the grid and the near half the editor, so when the phone folds back towards tabletop nothing has to move across the crease.")
        raw = full
    if theta <= 110:
        top_html = top
        bot_html = '<div style="width:669px;height:475.5px;transform:rotate(180deg)">%s</div>' % bot
    else:
        top_html = '<div style="width:669px;height:475.5px;overflow:hidden">%s</div>' % top
        bot_html = bot
    ST = stage_for(theta)
    scene = scene3d(theta, top_html, bot_html, ST["left"], ST["top"], ST["width"], ST["height"], ST["elev"], ST["az"], ST["zoom"], ST["shift_y"])
    # labels anchored to the half centres
    fx, fy = project((0, 205), theta, True)
    nx, ny = project((0, 205), theta, False)
    lab = ('<div class="abs" style="left:%spx;top:%spx;width:420px"><span class="tag p">%s</span><div class="cap" style="margin-top:8px">%s</div></div>'
           '<div class="abs" style="left:%spx;top:%spx;width:420px"><span class="tag a">%s</span><div class="cap" style="margin-top:8px">%s</div></div>'
           % (fx + 420, fy - 260, lab_far[0], lab_far[1], nx + 460, ny + 140, lab_near[0], lab_near[1]))
    leads = ('<svg class="abs" style="left:0;top:0" width="2400" height="1600">'
             '<path d="M%s %s L%s %s" stroke="rgba(241,242,244,.5)" stroke-width="1.5" fill="none"/><circle cx="%s" cy="%s" r="6" fill="#F1F2F4"/>'
             '<path d="M%s %s L%s %s" stroke="rgba(70,169,143,.8)" stroke-width="1.5" fill="none"/><circle cx="%s" cy="%s" r="6" fill="#46A98F"/></svg>'
             % (fx + 416, fy - 226, fx, fy, fx, fy, nx + 456, ny + 156, nx, ny, nx, ny))
    # screen map on the right
    ms = 0.58
    mapw, maph = 669*ms, 951*ms
    mx, my = 2400 - 80 - mapw, 330
    smap = ('<div class="abs" style="left:%spx;top:%spx"><div class="row" style="gap:12px;margin-bottom:14px"><span class="tag n">What the app draws</span><span class="cap">669 × 951 pt</span></div>'
            '<div class="shot" style="width:%spx;height:%spx;border-radius:22px;overflow:hidden;position:relative;outline:1px solid rgba(241,242,244,.1)"><div style="transform:scale(%s);transform-origin:0 0">%s</div>'
            '<div class="abs" style="left:0;right:0;top:%spx;border-top:1.5px dashed rgba(70,169,143,.7)"></div></div>'
            '<div class="row" style="justify-content:space-between;margin-top:12px"><span class="cap">↑ far half</span><span class="cap" style="color:#46A98F">fold · 475.5 pt</span><span class="cap">near half ↓</span></div></div>'
            % (mx, my, mapw, maph, ms, raw, 475.5*ms))
    body = (header("03", "Transition · %d°" % theta, sub) + scene + leads + lab + smap +
            '<div class="angle" style="left:80px;top:1330px">%d°<small>hinge angle</small></div>' % theta +
            '<div class="abs" style="left:420px;top:1350px;width:1000px"><div class="cap">%s</div></div>' % note +
            footer(SPEC + " · frames at 90 / 135 / 180"))
    return page('<div class="mock">%s</div>' % body, w=2400, h=1600, bg="#1a1b1e")

# ---------------------------------------------------------------- 04 closed + recap
def mock_04():
    s1, s2 = 1.36, 1.24
    body = (header("04", "Closed", "Fold it shut: the talk is over, the recap is already sent. Left: the Duo's outer display. Right: the recap on a recipient's iPhone") +
            '<div class="abs" style="left:250px;top:250px"><div class="row" style="gap:12px;margin-bottom:22px"><span class="tag p">Closed · outer display</span><span class="cap">466 × 678 pt @3x</span></div>%s</div>'
            % frame("duo-closed", ended_screen(), s1) +
            '<div class="abs" style="left:1520px;top:180px"><div class="row" style="gap:12px;margin-bottom:22px"><span class="tag a">Recipient\'s iPhone · Mail</span><span class="cap">402 × 874 pt</span></div>%s</div>'
            % frame("iphone", mail_iphone(), s2) +
            '<svg class="abs" style="left:0;top:0" width="2400" height="1600"><path d="M1010 1000 C 1180 1000, 1260 960, 1420 960" fill="none" stroke="rgba(70,169,143,.8)" stroke-width="2" stroke-dasharray="6 7"/><path d="M1406 950 L1424 960 L1406 970" fill="none" stroke="#46A98F" stroke-width="2"/><text x="1215" y="1040" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="14" text-anchor="middle">recap goes out on close</text></svg>'
            '<div class="abs" style="left:1040px;top:520px;width:340px"><div class="cap"><b>Trigger.</b> Hinge under 25° while a session is live. The email goes out at once; Undo holds for 30 s on the outer display.</div>'
            '<div class="cap" style="margin-top:14px"><b>Body.</b> Subject plus five lines from <code style="font:500 14px ui-monospace,Menlo;color:#F1F2F4">deck/recap-template.md</code>, then Mail\'s own link preview.</div>'
            '<div class="cap" style="margin-top:14px"><b>Also rendered</b> on the Duo\'s outer display (<code style="font:500 14px ui-monospace,Menlo;color:#F1F2F4">raw/recap-mail-duo-outer</code>) for holding the phone up on stage.</div></div>' +
            footer("Outer display 466 × 678 pt @3x (1398 × 2034 px) · iPhone 402 × 874 pt @3x"))
    return page('<div class="mock">%s</div>' % body, w=2400, h=1600, bg="#1a1b1e")

# ---------------------------------------------------------------- 05 laser dot
def finger_html(x, y, angle=-28):
    return ('<div class="abs" style="left:%spx;top:%spx;transform:rotate(%sdeg);transform-origin:0 0;filter:drop-shadow(0 26px 30px rgba(0,0,0,.5)) drop-shadow(0 4px 8px rgba(0,0,0,.3))">'
            '<div class="abs" style="left:-46px;top:-420px;width:92px;height:438px;border-radius:46px 46px 48px 48px / 40px 40px 52px 52px;background:linear-gradient(90deg,#b7805e 0%%,#dfa886 38%%,#e6b391 55%%,#c48b69 100%%);box-shadow:inset -8px 0 18px rgba(0,0,0,.12),inset 6px 0 12px rgba(255,255,255,.15)"></div>'
            '<div class="abs" style="left:-24px;top:-96px;width:50px;height:64px;border-radius:24px 24px 26px 26px / 30px 30px 34px 34px;background:linear-gradient(180deg,#f4d6c4,#e9bda6);box-shadow:inset 0 0 0 1.5px rgba(160,100,70,.25)"></div>'
            '<div class="abs" style="left:-46px;top:-300px;width:92px;height:2px;background:rgba(120,70,45,.18);border-radius:2px"></div>'
            '</div>' % (x, y, angle))

def mock_05():
    s = 1.55
    u, v = 0.30, 0.42
    pres = presenter_half(3, laser=(u, v))
    aud = audience_half(3, laser=(u, v))
    lx, ly = 80, 330
    rx, ry = 1283, 330
    padx, pady = lx + s*(20 + 432 + u*197), ly + s*(72 + 154 + v*217)
    dotx, doty = rx + s*(16 + u*637), ry + s*(30 + v*334.4)
    left_lbl = '<div class="row" style="gap:14px;position:absolute;top:-72px;left:0"><span class="tag p">Presenter half · your finger</span><span class="cap">trackpad 197 × 217 pt, top-right of the far half</span></div>'
    right_lbl = '<div class="row" style="gap:14px;position:absolute;top:-72px;left:0"><span class="tag a">Audience half · the dot</span><span class="cap">shown un-rotated, as the room sees it</span></div>'
    body = (header("05", "Laser dot", "Touch the trackpad on your half; a red dot appears at the same normalised point on the slide across the table") +
            half_panel(pres, lx, ly, s, "38px 38px 6px 6px", left_lbl, "bottom") +
            half_panel(aud, rx, ry, s, "38px 38px 38px 38px", right_lbl, "bottom") +
            '<svg class="abs" style="left:0;top:0" width="2400" height="1600"><path d="M%s %s C %s %s, %s %s, %s %s" fill="none" stroke="rgba(255,59,48,.75)" stroke-width="2" stroke-dasharray="7 8"/>'
            '<circle cx="%s" cy="%s" r="9" fill="none" stroke="rgba(255,59,48,.9)" stroke-width="2"/><circle cx="%s" cy="%s" r="9" fill="none" stroke="rgba(255,59,48,.9)" stroke-width="2"/></svg>'
            % (padx, pady, padx+260, pady-140, dotx-260, doty-140, dotx, doty, padx, pady, dotx, doty) +
            finger_html(padx, pady) +
            '<div class="abs" style="left:80px;top:1140px;width:1100px"><div class="cap"><b>Mapping.</b> pad (u, v) → slide (u · 637, v · 334) pt; here (0.30, 0.42). No pointer acceleration: the pad is a scaled map of the slide, so the dot goes where the finger is. Touch down shows the dot, lift hides it after 400 ms. The pad also echoes the dot under the finger.</div>'
            '<div class="cap" style="margin-top:14px"><b>Reach.</b> Your hand comes over the near half, so the pad sits in the top-right of the far half, nearest your fingertip. Left-handed mirror in settings.</div></div>' +
            '<div class="abs" style="left:1283px;top:1140px;width:1037px"><div class="cap"><b>Colour.</b> Signal red <code style="font:500 14px ui-monospace,Menlo;color:#F1F2F4">#FF3B30</code> with a soft glow, the only colour outside the brand palette, because a verdigris dot on a white slide does not read as a pointer. Diameter 16 pt, glow 18 pt.</div>'
            '<div class="cap" style="margin-top:14px"><b>Recap.</b> Every point the dot rested on for over a second is logged with its slide, for the "moments you pointed at" line if the template ever grows one.</div></div>' +
            footer(SPEC))
    return page('<div class="mock">%s</div>' % body, w=2400, h=1600, bg="#1a1b1e")

# ---------------------------------------------------------------- 06 flow diagram
def pose_glyph(theta, size=110, col_a="#46A98F", col_p="#F1F2F4"):
    cx, cy, L = size/2, size*0.86, size*0.62
    a = math.radians(theta/2)
    if theta < 8:
        return ('<svg width="%s" height="%s" viewBox="0 0 %s %s"><line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="9" stroke-linecap="round"/><line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="9" stroke-linecap="round"/></svg>'
                % (size, size, size, size, cx-5, cy, cx-5, cy-L, col_a, cx+5, cy, cx+5, cy-L, col_p))
    return ('<svg width="%s" height="%s" viewBox="0 0 %s %s"><line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="9" stroke-linecap="round"/><line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="9" stroke-linecap="round"/></svg>'
            % (size, size, size, size, cx, cy, cx - L*math.sin(a), cy - L*math.cos(a), col_a, cx, cy, cx + L*math.sin(a), cy - L*math.cos(a), col_p))

def mock_06():
    X0, X1 = 380, 2260
    def X(a): return X0 + (X1 - X0) * a / 180.0
    yE, yP, yD = 560, 790, 1020          # row centres: Edit, Present, Ended
    band_h = 170
    rows = [("Edit", yE, "Inner display, flat. Deck grid on the far half, notes + cue editor on the near half."),
            ("Present", yP, "Inner display, standing V. Far half: notes, cue, clock, laser pad. Near half: the slide, rotated 180°."),
            ("Ended", yD, "Outer display, closed. “Meeting ended, recap sent” with Undo for 30 s.")]
    g = []
    # vertical bands
    bands = [(0, 25, "rgba(241,242,244,.05)"), (25, 40, "rgba(241,242,244,.03)"), (40, 110, "rgba(70,169,143,.13)"), (110, 160, "url(#ramp)"), (160, 180, "rgba(241,242,244,.07)")]
    for a0, a1, fill in bands:
        g.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (X(a0), yE - band_h/2 - 40, X(a1) - X(a0), yD - yE + band_h + 80, fill))
    # hatch for hysteresis zone 25-40
    g.append('<rect x="%s" y="%s" width="%s" height="%s" fill="url(#hatch)"/>' % (X(25), yE - band_h/2 - 40, X(40) - X(25), yD - yE + band_h + 80))
    # row guides + labels
    for name, y, desc in rows:
        g.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="rgba(241,242,244,.10)" stroke-width="1"/>' % (X0, y, X1, y))
        g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="26" font-weight="600" text-anchor="end">%s</text>' % (X0 - 40, y + 9, name.upper()))
    # step line
    path = "M%s %s L%s %s L%s %s L%s %s L%s %s L%s %s" % (X(0), yD, X(40), yD, X(40), yP, X(110), yP, X(160), yE, X(180), yE)
    g.append('<path d="%s" fill="none" stroke="#F1F2F4" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"/>' % path)
    # hysteresis: re-entry from ended at 40
    g.append('<path d="M%s %s L%s %s L%s %s" fill="none" stroke="#9AA3AE" stroke-width="3" stroke-dasharray="8 8"/>' % (X(40), yP, X(25), yP, X(25), yD))
    g.append('<path d="M%s %s l-10 -18 h20 z" fill="#9AA3AE"/>' % (X(25), yD - 6))
    g.append('<path d="M%s %s l-18 -10 v20 z" fill="#F1F2F4"/>' % (X(40) + 40, yP))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="15" text-anchor="middle">closing: Present → Ended at 25°</text>' % (X(25), yD + 62))
    g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="15" text-anchor="start">opening: Ended → Present at 40° · 15° of hysteresis</text>' % (X(40) + 14, yP + 44))
    # breakpoints
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="20" font-weight="600" text-anchor="middle">25°</text>' % (X(25), yP - 28))
    for a, y, lab in [(40, yP, "40°"), (110, yP, "110°"), (160, yE, "160°")]:
        g.append('<circle cx="%s" cy="%s" r="9" fill="#111418" stroke="#F1F2F4" stroke-width="4"/>' % (X(a), y))
        g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="20" font-weight="600" text-anchor="middle">%s</text>' % (X(a), y - 28, lab))
    # ramp annotation
    g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="17" font-weight="600" text-anchor="middle">transition · t = (θ − 110) / 50</text>' % (X(135), yE - band_h/2 - 62))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="15" text-anchor="middle">near half un-rotates at 110° · notes slide under the fold · slide shrinks into its grid slot</text>' % (X(135), yE - band_h/2 - 38))
    g.append('<text x="%s" y="%s" fill="#46A98F" font-family="-apple-system,system-ui" font-size="17" font-weight="600" text-anchor="middle">PRESENT · 40° to 110°</text>' % (X(75), yE - band_h/2 - 62))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="15" text-anchor="middle">90° is the working pose · tolerant to ±20° of wobble</text>' % (X(75), yE - band_h/2 - 38))
    g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="17" font-weight="600" text-anchor="middle">EDIT</text>' % (X(170), yE - band_h/2 - 62))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="15" text-anchor="middle">160° to 180°</text>' % (X(170), yE - band_h/2 - 38))
    g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="17" font-weight="600" text-anchor="middle">ENDED</text>' % (X(12.5), yE - band_h/2 - 62))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="15" text-anchor="middle">under 25°</text>' % (X(12.5), yE - band_h/2 - 38))
    # axis
    yA = yD + band_h/2 + 50
    g.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="rgba(241,242,244,.4)" stroke-width="2"/>' % (X0, yA, X1, yA))
    for a in range(0, 181, 15):
        big = a % 45 == 0
        g.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="rgba(241,242,244,%s)" stroke-width="2"/>' % (X(a), yA, X(a), yA + (16 if big else 9), .6 if big else .3))
        if big:
            g.append('<text x="%s" y="%s" fill="#F1F2F4" font-family="-apple-system,system-ui" font-size="22" font-weight="600" text-anchor="middle">%d°</text>' % (X(a), yA + 46, a))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="16" text-anchor="middle">hinge angle · DeviceHinge.angle / UIHinge.angle · 0° closed, 180° flat</text>' % ((X0 + X1)/2, yA + 78))
    # system status strip
    yS = yA + 118
    for a0, a1, name in [(0, 10, ".closed"), (10, 170, ".partiallyOpen"), (170, 180, ".fullyOpen")]:
        g.append('<rect x="%s" y="%s" width="%s" height="34" rx="6" fill="rgba(241,242,244,.07)" stroke="rgba(241,242,244,.18)"/>' % (X(a0) + 2, yS, X(a1) - X(a0) - 4))
        g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="ui-monospace,Menlo,monospace" font-size="15" text-anchor="middle">%s</text>' % ((X(a0) + X(a1))/2, yS + 23, name))
    g.append('<text x="%s" y="%s" fill="#9AA3AE" font-family="-apple-system,system-ui" font-size="15" text-anchor="end">hinge.status ≈ · boundaries unpublished, read them, never hard-code</text>' % (X1, yS - 10))
    defs = ('<defs><linearGradient id="ramp" x1="0" x2="1"><stop offset="0" stop-color="rgba(70,169,143,.13)"/><stop offset="1" stop-color="rgba(241,242,244,.07)"/></linearGradient>'
            '<pattern id="hatch" width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="12" stroke="rgba(241,242,244,.12)" stroke-width="3"/></pattern></defs>')
    svg_ = '<svg class="abs" style="left:0;top:0" width="2400" height="1600">%s%s</svg>' % (defs, "".join(g))
    # row descriptions (HTML, right-aligned column under labels? place at left under each label)
    descs = "".join('<div class="abs" style="left:60px;top:%spx;width:260px;text-align:right"><div class="cap" style="font-size:14px;line-height:19px">%s</div></div>' % (y + 20, d) for _, y, d in rows)
    # poses
    yG = 1352
    poses = [(0, "Closed", "outer display"), (90, "Standing V", "the presenting pose"), (135, "Opening", "layout swapping"), (180, "Flat", "on the table")]
    ph = "".join('<div class="abs" style="left:%spx;top:%spx;width:200px;text-align:center"><div style="display:flex;justify-content:center">%s</div><div style="font:600 15px/18px var(--sans);color:#F1F2F4">%s</div><div class="cap" style="font-size:13px;line-height:16px">%s</div></div>'
                 % (X(a) - 100, yG, pose_glyph(a, 84), n, d) for a, n, d in poses)
    body = (header("06", "Hinge angle → app mode", "One page: which angle ranges map to present, edit and ended, with the hysteresis and the transition ramp") +
            svg_ + descs + ph +
            '<div class="abs" style="left:80px;top:1500px;width:2240px"><div class="cap">Ended fires only while a session is live (elapsed over 60 s, or the close slide’s cue was heard); closing an idle phone just quits to the outer display. Opening again past 40° within 30 s cancels the send. Transition is interpolated from the live angle, so a slow fold is a slow morph.</div></div>' +
            footer("Angles in degrees between the halves · thresholds are Flipside’s, not Apple’s · Apple: onHingeChange (SwiftUI) / UIHingeInteraction (UIKit)"))
    return page('<div class="mock">%s</div>' % body, w=2400, h=1600, bg="#1a1b1e")

# ---------------------------------------------------------------- contact sheet
def contact_sheet(files):
    tiles = []
    for f, cap in files:
        tiles.append('<div><div style="width:700px;height:467px;border-radius:14px;overflow:hidden;background:#000;box-shadow:0 10px 30px rgba(0,0,0,.4)"><img src="file://%s" style="width:700px;height:467px;object-fit:cover;display:block"></div><div style="font:400 14px/18px ui-monospace,Menlo,monospace;color:#9AA3AE;margin-top:10px">%s</div></div>' % (f, cap))
    inner = [r for r in sorted(RAW.glob("*.png")) if "669x951" in r.name]
    other = [r for r in sorted(RAW.glob("*.png")) if "669x951" not in r.name]
    def row(rs, h):
        return '<div style="display:flex;gap:12px;align-items:flex-start">%s</div>' % "".join(
            '<div><div style="height:%spx;border-radius:6px;overflow:hidden;background:#000;box-shadow:0 4px 14px rgba(0,0,0,.5)"><img src="file://%s" style="height:%spx;display:block"></div><div style="font:400 10px/13px ui-monospace,Menlo,monospace;color:#7f8894;margin-top:5px;max-width:%spx;overflow:hidden;white-space:nowrap;text-overflow:ellipsis">%s</div></div>' % (h, r, h, h*0.72, r.name.split("_")[0]) for r in rs)
    rawtile = ('<div><div style="width:700px;height:467px;border-radius:14px;background:#1d1e22;padding:18px 20px;box-sizing:border-box;display:flex;flex-direction:column;gap:14px">'
               '<div style="font:500 11px/13px var(--sans);letter-spacing:.08em;color:#9AA3AE;text-transform:uppercase">raw/ · exact point sizes @3x</div>%s%s</div>'
               '<div style="font:400 14px/18px ui-monospace,Menlo,monospace;color:#9AA3AE;margin-top:10px">raw/*.png · inner 2007×2853 · outer 1398×2034 · iPhone 1206×2622</div></div>' % (row(inner, 190), row(other, 190)))
    body = ('<div style="width:2400px;height:1700px;background:#151618;color:#F1F2F4;position:relative;font-family:var(--sans);padding:56px 60px">'
            '<div class="row" style="justify-content:space-between"><div><div style="font:400 40px/1 var(--serif)">Flipside · UI mockups · contact sheet</div><div style="font:400 16px/1 var(--sans);color:#9AA3AE;margin-top:10px">%s · ~/flipside-assets/ui · %s</div></div>%s</div>'
            '<div style="display:grid;grid-template-columns:repeat(3,700px);gap:26px 30px;margin-top:36px">%s%s</div></div>' % (DATE, SPEC, wordmark(30, True), "".join(tiles), rawtile))
    return page(body, w=2400, h=1700, bg="#151618")

MOCKS = [
    ("01-present-mode", mock_01),
    ("02-edit-mode", mock_02),
    ("03a-transition-090", lambda: mock_03(90)),
    ("03b-transition-135", lambda: mock_03(135)),
    ("03c-transition-180", lambda: mock_03(180)),
    ("04-closed-recap-sent", mock_04),
    ("05-laser-dot", mock_05),
    ("06-flow-hinge-angle-to-mode", mock_06),
]

def build_mocks(names=None):
    jobs = []
    for name, fn in MOCKS:
        if names and not any(n in name for n in names): continue
        p = write_html(name, fn())
        jobs.append((p, OUT / (name + ".png")))
    def run(j):
        p, out = j
        shot(p, out, 2400, 1600, 1)
        return out, png_size(out)
    with ThreadPoolExecutor(3) as ex:
        for out, size in ex.map(run, jobs):
            print(out.name, size)

def build_contact():
    files = [(OUT / (n + ".png"), n + ".png") for n, _ in MOCKS if (OUT / (n + ".png")).exists()]
    p = write_html("contact-sheet", contact_sheet(files))
    out = shot(p, OUT / "contact-sheet.png", 2400, 1700, 1)
    print(out.name, png_size(out))

def write_summary():
    lines = ["# Flipside UI mockups — SUMMARY", "", "Built %s by the UI mockups session. Everything here is an image or a note; no app code." % datetime.datetime.now().strftime("%d %b %Y %H:%M"), "",
             "Decisions and rationale: `../DECISIONS.md` (section “UI mockups job”), copy in `DECISIONS.md` here. Regenerate: `python3 _src/build.py`.", "",
             "## Look at these first",
             "1. `contact-sheet.png` — everything on one page.",
             "2. `03a-transition-090.png` — the pose. I drew the phone standing on its hinge as a V (each person sees the far inner half). If you meant something else, say so; it is one parameter.",
             "3. `01-present-mode.png` — the two halves as the app draws them: top half presenter (upright), bottom half audience (rotated 180°).",
             "4. `06-flow-hinge-angle-to-mode.png` — the angle thresholds (Ended < 25°, Present 25–110°, transition 110–160°, Edit 160–180°, re-enter Present at 40°).",
             "5. Slides carry `deck/deck.json` as finalised by the deck session at 01:45 (snapshot in `_src/deck-snapshot.json`); colours and the mark follow `brand/tokens.json` v0.2.0-refined (snapshot in `_src/tokens-snapshot.json`).", "",
             "## Display sizes used",
             "- Inner display: **669 × 951 pt @3x = 2007 × 2853 px** (App Store Connect inner screenshot size; confirmed against the booted Duo simulator framebuffer). Panel is 1878 × 2670 px; the OS downsamples. Hinge horizontal at 475.5 pt; each half 669 × 475.5 pt.",
             "- Outer display: 466 × 678 pt @3x = 1398 × 2034 px.",
             "- Second phone (recipient): iPhone 402 × 874 pt @3x.", "",
             "## Every file"]
    for p in sorted(OUT.glob("*.png")) + sorted(RAW.glob("*.png")):
        w, h = png_size(p)
        lines.append("- `%s`  %d×%d  %d KB" % (p.relative_to(OUT), w, h, p.stat().st_size // 1024))
    lines += ["- `DECISIONS.md`  copy of my section of the shared log", "- `SUMMARY.md`  this file", "- `_src/`  the generator (Python + HTML/CSS, fonts copied from `../build/fonts`), not app code", "",
              "## Missing or provisional",
              "- The HIG diagrams for the outer display (camera corner, vertical status bar) could not be downloaded (asset CDN returned 403), so the outer-display chrome in `04` and `raw/ended-outer*` follows the HIG text only.",
              "- The keyboard is not drawn in edit mode; the editor scrolls under it.",
              "- Fold gutter is an assumed 16 pt per side; the app should read `ReservedRegion(kind: .division)`.",
              "- Slide renders are mine (deck.json on the brand templates), not the deck session’s PNGs; same content, not pixel-identical.",
              "- The pose (V on the hinge, each viewer sees the far inner half) is my geometric reading of “stands on its edge, both halves inner display, one faces each side”. A real tent (hinge up) puts the inner display face-down; if you meant the outer display for the audience, the audience half becomes 466 × 678 pt and the presenter loses the notes half.",
              "- `raw/` has no separate 90° file: the 90° frame draws exactly `present_669x951pt@3x.png`.", "",
              "## Nothing failed",
              "All deliverables rendered on the first pipeline (headless Chrome, already installed). No installs, no sudo. One `%` escaping bug in the 3D scene and five layout nits were caught in visual QA and fixed."]
    (OUT / "SUMMARY.md").write_text("\n".join(lines) + "\n")
    print("SUMMARY.md written")

if __name__ == "__main__":
    args = sys.argv[1:]
    t0 = time.time()
    if not args or "raw" in args:
        raw_screens.render(None, 3)
    names = [a for a in args if a != "raw"]
    if not args or names:
        build_mocks(names or None)
    if not args or "contact" in args:
        build_contact()
        write_summary()
    print("done in %.1fs" % (time.time() - t0))
