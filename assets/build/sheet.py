import os, subprocess, datetime
S=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.expanduser("~/flipside-assets/brand"); FONTS=f"{S}/fonts"
def f(p): return f"file://{OUT}/{p}"
mark=open(f"{OUT}/mark/flipside-mark.svg").read(); markd=open(f"{OUT}/mark/flipside-mark-dark.svg").read(); mono=open(f"{OUT}/mark/flipside-mark-mono.svg").read()
W,H=2400,3800
css=f'''@font-face{{font-family:"Instrument Serif";src:url("file://{FONTS}/InstrumentSerif-Regular.woff") format("woff")}}
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#111418;-webkit-font-smoothing:antialiased}}
.wrap{{padding:56px 64px;box-sizing:border-box}}
.hdr{{display:flex;justify-content:space-between;align-items:flex-end;border-bottom:1px solid rgba(17,20,24,.12);padding-bottom:24px;margin-bottom:40px}}
.hdr h1{{font:400 44px/1 "Instrument Serif",serif;margin:0}} .hdr .m{{font:400 15px/1.5 -apple-system;color:#5F6875;text-align:right}}
.lbl{{font:500 13px/1 -apple-system;letter-spacing:.1em;text-transform:uppercase;color:#5F6875;margin:0 0 16px}}
.sec{{margin-bottom:44px}}
.row{{display:flex;gap:24px;align-items:flex-start}}
.card{{border-radius:14px;overflow:hidden;box-shadow:0 0 0 1px rgba(17,20,24,.16)}}
.panel{{background:#E3E5E9;border-radius:18px;padding:24px;box-sizing:border-box}}
.cap{{font:400 13px/1.5 -apple-system;color:#5F6875;margin-top:8px}}
.ios{{border-radius:22.37%;overflow:hidden;box-shadow:inset 0 0 0 1px rgba(17,20,24,.08)}}
.grid2{{display:grid;grid-template-columns:1fr 1fr;gap:24px}} .grid4{{display:grid;grid-template-columns:repeat(4,1fr);gap:24px}}
img{{display:block}}
.sizes{{display:flex;align-items:flex-end;gap:28px;background:#F1F2F4;border-radius:14px;padding:24px;height:112px;box-sizing:border-box}}
.sizesd{{background:#111418}}
.note{{font:400 15px/1.55 -apple-system;color:#111418;max-width:1104px}} .note b{{font-weight:500}}
.foot{{border-top:1px solid rgba(17,20,24,.12);padding-top:20px;font:400 13px/1.6 -apple-system;color:#5F6875}}
'''
def sizes(svgs, dark=False):
    cells=""
    for sv,w in svgs:
        sv2=sv.replace("<svg ", "<svg style='width:%dpx;height:%dpx' " % (w,w), 1)
        cells+="<div style='width:%dpx;height:%dpx'>%s</div>" % (w,w,sv2)
    return "<div class='sizes%s'>%s</div>" % (" sizesd" if dark else "", cells)
body=f'''<div class="wrap">
<div class="hdr"><div><h1>Flipside — brand &amp; visual system</h1><div class="cap" style="margin-top:10px">Refined pass · contact sheet · generated {datetime.date.today():%d %b %Y}</div></div>
<div class="m">~/flipside-assets/brand<br>tokens.json · README.md · SUMMARY.md</div></div>

<div class="sec"><p class="lbl">1 · Mark and wordmark — the phone in tent mode from the audience side: slide face stands in the accent, notes face reclines behind the ridge in ink</p>
<div class="row">
 <div><div class="card"><img src="{f('mark/flipside-wordmark-light.png')}" width="{int(open(f'{OUT}/mark/flipside-wordmark.svg').read().split('width="')[1].split('"')[0])+96}"></div><div class="cap">mark/flipside-wordmark.svg · text outlined, Instrument Serif</div></div>
 <div><div class="card"><img src="{f('mark/flipside-wordmark-dark.png')}" width="{int(open(f'{OUT}/mark/flipside-wordmark.svg').read().split('width="')[1].split('"')[0])+96}"></div><div class="cap">mark/flipside-wordmark-dark.svg</div></div>
 <div style="flex:1"><div class="row">{sizes([(mark,64),(mark,44),(mark,28),(mark,16),(mono,44)])}{sizes([(markd,64),(markd,44),(markd,28),(markd,16)],True)}</div><div class="cap">mark at 64 / 44 / 28 / 16 px, plus the mono variant (crease as a knockout gap)</div></div>
</div></div>

<div class="sec"><p class="lbl">2 · App icon — 1024 px, solid background, iOS applies the corner mask</p>
<div class="row">
 <div><div class="ios" style="width:300px;height:300px"><img src="{f('icon/flipside-icon-light-1024.png')}" width="300"></div><div class="cap">icon/flipside-icon-light-1024.png</div></div>
 <div><div class="ios" style="width:300px;height:300px"><img src="{f('icon/flipside-icon-dark-1024.png')}" width="300"></div><div class="cap">icon/flipside-icon-dark-1024.png</div></div>
 <div style="display:flex;gap:20px;align-items:flex-end;background:#F1F2F4;border-radius:14px;padding:24px;height:300px;box-sizing:border-box">
   <div class="ios" style="width:120px;height:120px"><img src="{f('icon/flipside-icon-light-1024.png')}" width="120"></div>
   <div class="ios" style="width:60px;height:60px"><img src="{f('icon/flipside-icon-light-1024.png')}" width="60"></div>
   <div class="ios" style="width:60px;height:60px"><img src="{f('icon/flipside-icon-dark-1024.png')}" width="60"></div>
   <div class="ios" style="width:29px;height:29px"><img src="{f('icon/flipside-icon-light-1024.png')}" width="29"></div>
 </div>
 <div class="note" style="max-width:700px;padding-top:8px"><b>Design logic.</b> Slides face the audience, notes face the presenter. The mark is the phone's presenting posture: folded into a tent on the table, the slide face standing toward the room in the accent, the notes face reclining behind the ridge in ink toward the presenter. Every surface repeats that crease quietly: a 1 px fold line, a lit face and a quiet face, a 3 px accent tab at the top like a bookmark.<br><br><b>Palette.</b> Cool near-neutral greys and one deep verdigris; built for a phone held up in a bright room. Same five roles mirrored dark for the presenter's side.<br><br><b>Type.</b> Instrument Serif for whatever the room reads (narrow forms suit a half-width screen), SF Pro for whatever the presenter reads and taps.</div>
</div></div>

<div class="sec"><div class="row">
 <div style="width:1124px"><p class="lbl">3 · Palette — five roles, light and the dark mirror</p><div class="card"><img src="{f('palette/palette.png')}" width="1124"></div>
   <p class="lbl" style="margin-top:32px">5 · Template backgrounds as delivered (no copy) · 1200×630</p>
   <div class="panel" style="width:1124px"><div class="grid2">{"".join(f'<div><div class="card"><img src="{f("templates/"+k+".png")}" width="514"></div><div class="cap">templates/{k}.png</div></div>' for k in ("title","statement","two-column","closing"))}</div></div>
 </div>
 <div style="width:1124px"><p class="lbl">4 · Type — Instrument Serif (display) + SF Pro (text), sizes in iOS points, shown at 2×</p><div class="card"><img src="{f('type/type-specimen.png')}" width="1124"></div></div>
</div></div>

<div class="sec"><p class="lbl">6 · Slide templates with sample copy — lit face carries content, quiet face stays Paper, crease at centre</p>
<div class="panel"><div class="grid2">{"".join(f'<div><div class="card"><img src="{f("templates/"+k+"-example.png")}" width="1100"></div><div class="cap">templates/{k}-example.png</div></div>' for k in ("title","statement","two-column","closing"))}</div></div></div>

<div class="foot">Colour: Paper #F1F2F4 · Card #FFFFFF · Ink #111418 · Graphite #5F6875 · Verdigris #0E6B5E &nbsp;·&nbsp; Dark mirror: Ink / Slate #1A1E24 / Paper / Ash #9AA3AE / Verdigris Light #3E9C85 &nbsp;·&nbsp; Fonts: Instrument Serif (Google Fonts, OFL), SF Pro (Apple system; Inter as web fallback) &nbsp;·&nbsp; All values in tokens.json</div>
</div>'''
html=f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'
hp=f"{S}/work/sheet.html"; open(hp,"w").write(html)
subprocess.run(["/bin/zsh",f"{S}/render.sh",hp,str(W),str(H),f"{OUT}/contact-sheet.png"],check=True)
print("sheet ok")
