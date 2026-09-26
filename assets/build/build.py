#!/usr/bin/env python3
"""Flipside brand build. Single source of truth: TOKENS below. Emits SVG/PNG/JSON/MD into ~/flipside-assets/brand."""
import json, math, os, subprocess, shutil, sys
S = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.expanduser("~/flipside-assets/brand")
FONTS = os.path.join(S, "fonts")
WORK = os.path.join(S, "work"); os.makedirs(WORK, exist_ok=True)
for d in ("mark","icon","templates","type","palette"): os.makedirs(os.path.join(OUT,d), exist_ok=True)

# ---------------------------------------------------------------- tokens
TOKENS = {
  "name": "Flipside",
  "version": "0.2.0-refined",
  "color": {
    "audience": {  # light theme: the face the room sees
      "background": {"name":"Paper",    "hex":"#F1F2F4", "role":"screen background"},
      "surface":    {"name":"Card",     "hex":"#FFFFFF", "role":"slides, sheets, lit face"},
      "text":       {"name":"Ink",      "hex":"#111418", "role":"primary text, marks"},
      "muted":      {"name":"Graphite", "hex":"#5F6875", "role":"secondary text, labels, notes"},
      "accent":     {"name":"Verdigris","hex":"#0E6B5E", "role":"the one accent: tabs, links, progress, the audience leg of the mark"}
    },
    "presenter": {  # dark mirror: the face the presenter sees
      "background": {"name":"Ink",      "hex":"#111418", "role":"screen background"},
      "surface":    {"name":"Slate",    "hex":"#1A1E24", "role":"cards, notes panel"},
      "text":       {"name":"Paper",    "hex":"#F1F2F4", "role":"primary text"},
      "muted":      {"name":"Ash",      "hex":"#9AA3AE", "role":"secondary text, timers, labels"},
      "accent":     {"name":"Verdigris Light","hex":"#3E9C85","role":"same accent, lifted for dark (5.5:1 on Ink, 5.0:1 on Slate); put Ink text on accent fills in this theme, not white"}
    },
    "crease": {"light":"rgba(17,20,24,0.12)", "dark":"rgba(241,242,244,0.14)", "role":"the 1px fold line"}
  },
  "type": {
    "display": {"family":"Instrument Serif","source":"Google Fonts","weights":["Regular","Italic"],"fallback":"New York, Georgia, serif"},
    "text":    {"family":"SF Pro","source":"Apple system (SF Pro Text / SF Pro Display)","weights":["Regular","Medium","Semibold"],"fallback":"Inter (Google Fonts) on web, then system-ui"},
    "scale_pt": {   # iOS points, one Duo half (~390pt wide assumed)
      "slideTitle":     {"face":"display","size":48,"lineHeight":52,"tracking":-0.01},
      "slideStatement": {"face":"display","style":"Italic","size":40,"lineHeight":46,"tracking":-0.005},
      "slideHeading":   {"face":"display","size":28,"lineHeight":32,"tracking":0},
      "slideBody":      {"face":"text","weight":"Regular","size":22,"lineHeight":30,"tracking":0},
      "presenterNotes": {"face":"text","weight":"Regular","size":17,"lineHeight":26,"tracking":0},
      "uiLabel":        {"face":"text","weight":"Medium","size":13,"lineHeight":16,"tracking":0.02,"case":"upper for section labels"},
      "caption":        {"face":"text","weight":"Regular","size":12,"lineHeight":16,"tracking":0.01}
    },
    "scale_canvas1200": {  # px on the 1200x630 export canvas
      "slideTitle":84, "slideStatement":60, "slideHeading":44, "slideBody":26, "uiLabel":17, "caption":15
    }
  },
  "space": {"base":4, "scale":[4,8,12,16,24,32,48,64,96], "slideMargin_pt":24, "slideMargin_canvas1200":64, "columnGutter_canvas1200":64},
  "radius": {"control":8, "card":14, "sheet":22, "icon":"system"},
  "mark": {"nearTilt_deg":24, "farTilt_deg":64, "yaw_deg":78, "pitch_deg":42, "halfAspect":"0.47 x 1.0 (slope x ridge)", "cornerRadius":3, "viewBox":100, "note":"the phone in tent mode seen from the audience side of the table, slightly above: the slide face stands steep in the accent, the notes face reclines behind the ridge in ink"},
  "crease_detail": {"line":"1px, color.crease", "tab":"accent 3x28 at top of crease", "litFace":"surface on the face that carries content, background on the quiet face"}
}
A = {k:v["hex"] for k,v in TOKENS["color"]["audience"].items()}
P = {k:v["hex"] for k,v in TOKENS["color"]["presenter"].items()}
CREASE_L = TOKENS["color"]["crease"]["light"]; CREASE_D = TOKENS["color"]["crease"]["dark"]

# ---------------------------------------------------------------- mark geometry (asymmetric tent seen from the audience side, slightly above)
MK=dict(near_tilt=24, far_tilt=64, yaw=78, pitch=42, slope=0.47, ridge=1.0, r=3.0, fill=78)
def _project(p,yaw,pitch):
    x,y,z=p; cy,sy=math.cos(yaw),math.sin(yaw); x1=x*cy+z*sy; z1=-x*sy+z*cy
    cp,sp=math.cos(pitch),math.sin(pitch); y2=y*cp-z1*sp
    return (x1,-y2)
def mark_faces(box=100, fill=None):
    fill=fill or MK["fill"]; r=MK["r"]; D=MK["ridge"]
    H=MK["slope"]*math.cos(math.radians(MK["near_tilt"])); Wn=MK["slope"]*math.sin(math.radians(MK["near_tilt"]))
    Wf=H*math.tan(math.radians(MK["far_tilt"]))
    near=[(0,H,-D/2),(0,H,D/2),(-Wn,0,D/2),(-Wn,0,-D/2)]     # audience face: steep, toward the room
    far=[(0,H,D/2),(0,H,-D/2),(Wf,0,-D/2),(Wf,0,D/2)]         # presenter face: reclined, toward whoever looks down at it
    y,p=math.radians(MK["yaw"]),math.radians(MK["pitch"])
    N=[_project(q,y,p) for q in near]; F=[_project(q,y,p) for q in far]
    xs=[q[0] for q in N+F]; ys=[q[1] for q in N+F]
    w=max(xs)-min(xs); h=max(ys)-min(ys); sc=(fill-2*r)/max(w,h)
    ox=box/2-(min(xs)+w/2)*sc; oy=box/2-(min(ys)+h/2)*sc
    f=lambda pts:[(q[0]*sc+ox,q[1]*sc+oy) for q in pts]
    N,F=f(N),f(F); xs=[q[0] for q in N+F]; ys=[q[1] for q in N+F]
    return N,F,(min(xs)-r,min(ys)-r,max(xs)+r,max(ys)+r)
def _poly(pts): return "M"+" L".join(f"{x:.2f} {y:.2f}" for x,y in pts)+" Z"
def mark_body(ink, acc, uid="m", box=100, width=None, gap=0, bg=None):
    N,F,_=mark_faces(box); r=MK["r"]
    o=f'<path d="{_poly(F)}" fill="{ink}" stroke="{ink}" stroke-width="{2*r}" stroke-linejoin="round"/>'
    if gap and bg: o+=f'<path d="{_poly(N)}" fill="none" stroke="{bg}" stroke-width="{2*r+gap}" stroke-linejoin="round"/>'
    o+=f'<path d="{_poly(N)}" fill="{acc}" stroke="{acc}" stroke-width="{2*r}" stroke-linejoin="round"/>'
    return o
def mark_geometry(box=100,width=None):
    N,F,(x0,y0,x1,y1)=mark_faces(box)
    return None, box/2, y0, y1-y0, None
def svg(w,h,body,viewbox=None):
    vb=viewbox or f"0 0 {w} {h}"
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{vb}">{body}</svg>'

def write(path, s):
    with open(path,"w") as f: f.write(s)

# mark SVGs (transparent bg, 100 box)
write(f"{OUT}/mark/flipside-mark.svg",      svg(100,100,mark_body(A["text"],A["accent"],"c")))
write(f"{OUT}/mark/flipside-mark-dark.svg", svg(100,100,mark_body(P["text"],P["accent"],"c")))
write(f"{OUT}/mark/flipside-mark-mono.svg", svg(100,100,mark_body(A["text"],A["text"],"c",gap=2.4,bg="white")))  # single colour: crease shown as a gap (knockout in white; recolour as needed)

# icon SVGs: 1024 box, solid bg, glyph ~ 560 wide, optically centred a hair low
def icon_svg(bg, ink, acc):
    g=mark_body(ink,acc,"ic",box=100)
    N,F,(x0,y0,x1,y1)=mark_faces(100); cx=(x0+x1)/2; cy=(y0+y1)/2
    # scale 100-box to 1024; visible glyph ~ 60% of the tile, bbox centred a hair low
    return svg(1024,1024,f'<rect width="1024" height="1024" fill="{bg}"/><g transform="translate(512 528) scale(8.4) translate({-cx:.2f} {-cy:.2f})">{g}</g>')
write(f"{OUT}/icon/flipside-icon-light.svg", icon_svg(A["background"],A["text"],A["accent"]))
write(f"{OUT}/icon/flipside-icon-dark.svg",  icon_svg(P["background"],P["text"],P["accent"]))

# ---------------------------------------------------------------- wordmark (text outlined with fontTools + harfbuzz)
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
import uharfbuzz as hb
def outline_text(ttf_path, text, size, x0, baseline, tracking_em=0.0):
    font=TTFont(ttf_path); upm=font["head"].unitsPerEm; gs=font.getGlyphSet(); order=font.getGlyphOrder()
    blob=hb.Blob.from_file_path(ttf_path); face=hb.Face(blob); hfont=hb.Font(face)
    buf=hb.Buffer(); buf.add_str(text); buf.guess_segment_properties(); hb.shape(hfont, buf, {"kern":True,"liga":True})
    k=size/upm; x=x0; paths=[]
    for info,pos in zip(buf.glyph_infos, buf.glyph_positions):
        gname=order[info.codepoint]
        pen=SVGPathPen(gs); tp=TransformPen(pen,(k,0,0,-k, x+pos.x_offset*k, baseline-pos.y_offset*k))
        gs[gname].draw(tp); paths.append(pen.getCommands())
        x+=pos.x_advance*k + tracking_em*size
    return " ".join(p for p in paths if p), x
def wordmark_svg(ink, acc, bg=None, uid="w"):
    size=96; cap=0.72*size; ttf=f"{FONTS}/InstrumentSerif-Regular.ttf"
    N,F,(x0,y0,x1,y1)=mark_faces(100); glyph_h=cap*1.02; sc=glyph_h/(y1-y0); gx=8
    g=f'<g transform="translate({gx-x0*sc:.2f} {88-y1*sc:.2f}) scale({sc:.4f})">{mark_body(ink,acc,uid)}</g>'
    text_x=gx+(x1-x0)*sc+0.2*size
    tpath,xend=outline_text(ttf,"Flipside",size,text_x,88,tracking_em=-0.012)
    w=math.ceil(xend+10)
    body=(f'<rect width="{w}" height="120" fill="{bg}"/>' if bg else "")+g+f'<path d="{tpath}" fill="{ink}"/>'
    return svg(w,120,body), w
wm_l,wm_w=wordmark_svg(A["text"],A["accent"])
wm_d,_=wordmark_svg(P["text"],P["accent"])
write(f"{OUT}/mark/flipside-wordmark.svg", wm_l)
write(f"{OUT}/mark/flipside-wordmark-dark.svg", wm_d)
# split-tone alternate (Flip | side) for review
def wordmark_split(ink, muted, acc, uid="ws"):
    size=96; cap=0.72*size; N,F,(x0,y0,x1,y1)=mark_faces(100); glyph_h=cap*1.02; sc=glyph_h/(y1-y0); gx=8
    g=f'<g transform="translate({gx-x0*sc:.2f} {88-y1*sc:.2f}) scale({sc:.4f})">{mark_body(ink,acc,uid)}</g>'
    ttf=f"{FONTS}/InstrumentSerif-Regular.ttf"; text_x=gx+(x1-x0)*sc+0.2*size
    p1,x1_=outline_text(ttf,"Flip",size,text_x,88,-0.012); p2,x2=outline_text(ttf,"side",size,x1_,88,-0.012)
    return svg(math.ceil(x2+10),120,g+f'<path d="{p1}" fill="{ink}"/><path d="{p2}" fill="{muted}"/>')
write(f"{WORK}/wordmark-split.svg", wordmark_split(A["text"],A["muted"],A["accent"]))

# ---------------------------------------------------------------- HTML helpers
FONTFACE=f'''@font-face{{font-family:"Instrument Serif";src:url("file://{FONTS}/InstrumentSerif-Regular.woff") format("woff");font-weight:400}}
@font-face{{font-family:"Instrument Serif";src:url("file://{FONTS}/InstrumentSerif-Italic.woff") format("woff");font-style:italic}}
@font-face{{font-family:"InterFB";src:url("file://{FONTS}/Inter-400.woff") format("woff");font-weight:400}}
@font-face{{font-family:"InterFB";src:url("file://{FONTS}/Inter-500.woff") format("woff");font-weight:500}}
:root{{--disp:"Instrument Serif",serif;--text:-apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro Display",InterFB,sans-serif}}'''
def page(w,h,css,body):
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{FONTFACE}html,body{{margin:0;width:{w}px;height:{h}px;overflow:hidden;-webkit-font-smoothing:antialiased}}{css}</style></head><body>{body}</body></html>'
def render(name,w,h,html,dest):
    hp=os.path.join(WORK,name+".html"); write(hp,html)
    subprocess.run(["/bin/zsh", os.path.join(S,"render.sh"), hp, str(w), str(h), dest], check=True)

# icons PNG 1024
for v,src in (("light",f"{OUT}/icon/flipside-icon-light.svg"),("dark",f"{OUT}/icon/flipside-icon-dark.svg")):
    render(f"icon-{v}",1024,1024,page(1024,1024,"body{background:transparent}", open(src).read()), f"{OUT}/icon/flipside-icon-{v}-1024.png")
# wordmark PNGs (3x for crispness) on solid bg
for v,src,bg in (("light",f"{OUT}/mark/flipside-wordmark.svg",A["background"]),("dark",f"{OUT}/mark/flipside-wordmark-dark.svg",P["background"])):
    s=open(src).read(); w=int(s.split('width="')[1].split('"')[0])
    W,H=(w+96)*2,(120+96)*2
    render(f"wordmark-{v}",W,H,page(W,H,f"body{{background:{bg};display:flex;align-items:center;justify-content:center}} svg{{width:{w*2}px;height:240px}}",s), f"{OUT}/mark/flipside-wordmark-{v}.png")

# ---------------------------------------------------------------- slide templates 1200x630
CV=TOKENS["type"]["scale_canvas1200"]; M=64
def slide_css(left_bg,right_bg,crease=CREASE_L,ink=A["text"],muted=A["muted"],acc=A["accent"]):
    return f'''body{{background:{left_bg};position:relative;font-family:var(--text);color:{ink}}}
.right{{position:absolute;left:600px;top:0;width:600px;height:630px;background:{right_bg}}}
.crease{{position:absolute;left:599.5px;top:0;width:1px;height:630px;background:{crease}}}
.tab{{position:absolute;left:598.5px;top:0;width:3px;height:28px;background:{acc}}}
.kicker{{position:absolute;font:500 {CV['uiLabel']}px/1.2 var(--text);letter-spacing:.08em;text-transform:uppercase;color:{muted}}}
.title{{position:absolute;font:400 {CV['slideTitle']}px/0.98 var(--disp);letter-spacing:-.01em;color:{ink}}}
.sub{{position:absolute;font:400 {CV['slideBody']}px/1.3 var(--text);color:{muted}}}
.stmt{{position:absolute;font:italic 400 {CV['slideStatement']}px/1.08 var(--disp);letter-spacing:-.005em;color:{ink}}}
.h{{position:absolute;font:400 {CV['slideHeading']}px/1.05 var(--disp);color:{ink}}}
.body{{position:absolute;font:400 {CV['slideBody']}px/1.4 var(--text);color:{ink}}}
.body p{{margin:0 0 14px}}
.cap{{position:absolute;font:400 {CV['caption']}px/1.3 var(--text);color:{muted}}}
.num{{position:absolute;font:400 {CV['slideHeading']}px/1 var(--disp);color:{muted}}}'''
def tmpl(kind, example):
    lit=A["surface"]; quiet=A["background"]
    if kind=="title":
        css=slide_css(lit,quiet); b='<div class="right"></div><div class="crease"></div><div class="tab"></div>'
        if example: b+=(f'<div class="kicker" style="left:{M}px;top:{M}px">Flipside · Q3 review</div>'
            f'<div class="title" style="left:{M}px;bottom:{M+52}px;width:472px">Why the best pitches are read, not watched</div>'
            f'<div class="sub" style="left:{M}px;bottom:{M}px;width:472px">Kartik Kapoor · 26 Sep 2026</div>')
    elif kind=="statement":
        css=slide_css(quiet,lit); b='<div class="right"></div><div class="crease"></div><div class="tab"></div>'
        if example: b+=(f'<div class="num" style="left:{M}px;top:{M}px">02</div>'
            f'<div class="stmt" style="left:{600+M}px;top:50%;transform:translateY(-50%);width:472px">A deck is a sentence that got longer. Start with the sentence.</div>')
    elif kind=="two-column":
        css=slide_css(lit,lit); b='<div class="right"></div><div class="crease"></div><div class="tab"></div>'
        if example: b+=(f'<div class="kicker" style="left:{M}px;top:{M}px">What we heard</div><div class="h" style="left:{M}px;top:{M+40}px;width:472px">Slides are for the room</div>'
            f'<div class="body" style="left:{M}px;top:{M+120}px;width:472px"><p>One idea per face. The audience reads the slide across a table; the presenter reads the notes at arm’s length.</p><p>Both faces come from the same sentence.</p></div>'
            f'<div class="kicker" style="left:{600+M}px;top:{M}px">What we’ll ship</div><div class="h" style="left:{600+M}px;top:{M+40}px;width:472px">Notes are for you</div>'
            f'<div class="body" style="left:{600+M}px;top:{M+120}px;width:472px"><p>Paste a link. Flipside writes the deck and the notes, then folds them across the two halves.</p><p>Tap the crease to swap faces.</p></div>')
    elif kind=="closing":
        css=slide_css(quiet,quiet); g=mark_body(A["text"],A["accent"],"cl")
        b=(f'<div class="right"></div><div class="crease" style="height:180px"></div><div class="crease" style="top:470px;height:160px"></div>'
           f'<div style="position:absolute;left:520px;top:180px;width:160px;height:160px"><svg viewBox="0 0 100 100" width="160" height="160">{g}</svg></div>')
        if example: b+=(f'<div class="title" style="left:0;top:330px;width:1200px;text-align:center;font-size:{CV["slideStatement"]}px">Thank you</div>'
            f'<div class="cap" style="left:0;top:412px;width:1200px;text-align:center;font-size:{CV["slideBody"]}px">flipside.app · Made from one link</div>')
    return page(1200,630,css,b)
for kind in ("title","statement","two-column","closing"):
    render(f"tmpl-{kind}",1200,630,tmpl(kind,False),f"{OUT}/templates/{kind}.png")
    render(f"tmpl-{kind}-example",1200,630,tmpl(kind,True),f"{OUT}/templates/{kind}-example.png")

# ---------------------------------------------------------------- palette + type specimen PNGs
def swatches(theme, title):
    c=TOKENS["color"][theme]; cells=""
    for role in ("background","surface","text","muted","accent"):
        v=c[role]; light=(role in("background","surface")) if theme=="audience" else (role in("text","accent"))
        fg=A["text"] if light else A["background"]
        if theme=="presenter" and role=="text": fg=P["background"]
        border=f'box-shadow:inset 0 0 0 1px {CREASE_L}' if theme=="audience" and role in("background","surface") else ""
        cells+=f'<div class="sw" style="background:{v["hex"]};color:{fg};{border}"><div class="role">{role}</div><div class="nm">{v["name"]}</div><div class="hex">{v["hex"]}</div></div>'
    return f'<div class="ttl">{title}</div><div class="row">{cells}</div>'
pal_css=f'''body{{background:#fff;padding:48px;box-sizing:border-box;font-family:var(--text);color:{A["text"]}}}
.ttl{{font:500 14px/1 var(--text);letter-spacing:.08em;text-transform:uppercase;color:{A["muted"]};margin:0 0 14px}}
.row{{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:36px}}
.sw{{height:150px;border-radius:14px;padding:16px;box-sizing:border-box;display:flex;flex-direction:column;justify-content:flex-end}}
.role{{font:500 13px/1.2 var(--text);letter-spacing:.06em;text-transform:uppercase;opacity:.8}}
.nm{{font:400 26px/1.1 var(--disp);margin-top:6px}} .hex{{font:400 13px/1.4 var(--text);opacity:.8;margin-top:2px}}'''
render("palette",1200,520,page(1200,520,pal_css,swatches("audience","Audience face · light")+swatches("presenter","Presenter face · dark mirror")),f"{OUT}/palette/palette.png")

sc=TOKENS["type"]["scale_pt"]; rows=""
for k,v in sc.items():
    fam="var(--disp)" if v["face"]=="display" else "var(--text)"; wt={"Regular":400,"Medium":500,"Semibold":600}.get(v.get("weight","Regular"),400)
    sample={"slideTitle":"The other side of the deck","slideStatement":"Say it once, say it well.","slideHeading":"What we heard","slideBody":"Slides face the room. Notes face you.","presenterNotes":"Pause here. Ask who has shipped a deck from a single link before moving on.","uiLabel":"SLIDE 4 OF 12 · 02:15","caption":"Generated from a link · edited by you"}[k]
    face="Instrument Serif" if v["face"]=="display" else "SF Pro"
    sty="italic " if v.get("style")=="Italic" else ""
    rows+=f'<div class="r"><div class="meta"><b>{k}</b><br>{face} {v.get("style",v.get("weight","Regular"))}<br>{v["size"]}/{v["lineHeight"]} pt · {v["tracking"]:+.3f}em</div><div class="smp" style="font:{sty}{wt} {v["size"]*2}px/{v["lineHeight"]*2}px {fam};letter-spacing:{v["tracking"]}em">{sample}</div></div>'
type_css=f'''body{{background:#fff;padding:48px;box-sizing:border-box;font-family:var(--text);color:{A["text"]}}}
.r{{display:grid;grid-template-columns:220px 1fr;gap:24px;align-items:baseline;padding:20px 0;border-bottom:1px solid {CREASE_L}}}
.meta{{font:400 13px/1.5 var(--text);color:{A["muted"]}}} .meta b{{color:{A["text"]};font-weight:500}} .smp{{max-width:820px}}'''
render("type",1200,1130,page(1200,1130,type_css,rows),f"{OUT}/type/type-specimen.png")

# ---------------------------------------------------------------- tokens + README
write(f"{OUT}/tokens.json", json.dumps(TOKENS, indent=2, ensure_ascii=False)+"\n")
readme=f'''# Flipside — brand & visual system (first pass)

Flipside turns a link or a sentence into a presentation and plays it across the two halves of a folded iPhone Duo: slides face the audience, notes face the presenter. The whole system is built from that one fact. The mark is the phone itself in tent mode, seen from the audience's side of the table: the slide face stands steep toward the room in the accent, the notes face reclines behind the ridge in ink, toward the presenter looking down at it. The halves are landscape, the same proportion as the slides. Every surface repeats that crease quietly. Slides carry a 1px fold line down the centre, the face that holds content is lit (Card white) while the other stays Paper, and a 3px accent tab sits at the top of the crease like a bookmark. Colour is a cool, near-neutral grey scale with a single deep verdigris accent, chosen to stay calm and legible on a phone held up in a bright room, with a dark mirror of the same five roles for the presenter's side (accent fills there take Ink text, not white). Type pairs Instrument Serif for anything the room reads (its narrow forms fit a half-width screen) with SF Pro for everything the presenter reads and taps, so the app ships with one bundled font and one system font.

## Files

- `mark/flipside-mark.svg`, `-dark.svg`, `-mono.svg` — the fold mark (100-unit viewBox, transparent)
- `mark/flipside-wordmark.svg`, `-dark.svg` (+ `.png` previews) — mark + "Flipside" in Instrument Serif, text outlined
- `icon/flipside-icon-light-1024.png`, `-dark-1024.png` (+ `.svg`) — app icon, solid background, no corner mask (iOS applies it)
- `palette/palette.png` — the five roles, light and dark mirror
- `type/type-specimen.png` — the type scale at 2x
- `templates/title.png`, `statement.png`, `two-column.png`, `closing.png` — 1200x630 backgrounds; `*-example.png` show sample copy in the system
- `tokens.json` — colour, type, spacing, radius and mark geometry
- `contact-sheet.png` — everything on one page

## Refinement round (26 Sep 2026, run unattended)

- Mark rebuilt. The first-pass end-on chevron read as a caret at 16 px and a chevron at 60 px and above, so it failed the one test that mattered: does it read as a folded phone standing on a table? The new mark is the same phone in tent mode seen from the audience's side and slightly above, with the slide face standing steep and the notes face reclining behind the ridge. That view keeps both faces visible at every size. The old mark is kept in `../build/alternates/v1-tent-endon`.
- Accent kept. Verdigris passes on Paper (5.7:1) and Card (6.4:1) and reads deeper and calmer than iOS blue beside it. Only the dark-theme variant changed, from #46A98F to #3E9C85, because the minty one looked cheap next to iOS blue; it is 5.5:1 on Ink and 5.0:1 on Slate. Accent-filled buttons in the dark theme take Ink text, since white on either variant fails.
- Italic kept on the statement slide; at 60 px on the 1200x630 canvas it is fully legible.

## Fonts

Instrument Serif: https://fonts.google.com/specimen/Instrument+Serif (OFL). SF Pro ships with iOS; use Inter (https://fonts.google.com/specimen/Inter) as the web fallback.
'''
write(f"{OUT}/README.md", readme)
print("built", OUT)
