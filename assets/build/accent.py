import os, subprocess
S=os.path.dirname(os.path.abspath(__file__)); W=os.path.join(S,"work")
def lum(h):
    h=h.lstrip('#'); r,g,b=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    f=lambda c: c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def cr(a,b): la,lb=lum(a),lum(b); return (max(la,lb)+0.05)/(min(la,lb)+0.05)
PAPER,CARD,INK,SLATE="#F1F2F4","#FFFFFF","#111418","#1A1E24"
V,VD="#0E6B5E","#46A98F"; BLUE,BLUED="#007AFF","#0A84FF"
alts={"VD current":"#46A98F","VD less minty":"#3E9C85","VD deeper":"#2F8F78","VD cooler":"#3FA093"}
print("contrast (WCAG):")
for name,a,b in [("Verdigris on Paper",V,PAPER),("Verdigris on Card",V,CARD),("white on Verdigris","#FFFFFF",V),("Verdigris on Ink (NOT used)",V,INK),
                 ("iOS blue on Paper",BLUE,PAPER),("iOS blue on Ink",BLUED,INK)]+[(k+" on Ink",v,INK) for k,v in alts.items()]+[(k+" on Slate",v,SLATE) for k,v in alts.items()]:
    print(f"  {name:32s} {cr(a,b):5.2f}:1")
def ui(bg,fg,acc,muted,label):
    return f'''<div class="ph" style="background:{bg};color:{fg}"><div class="lbl" style="color:{muted}">{label}</div>
<div class="btn" style="background:{acc}">Present</div><div class="lnk" style="color:{acc}">Open notes ›</div>
<div class="bar"><div style="width:62%;background:{acc}"></div></div><div class="tab" style="background:{acc}"></div>
<div class="sw"><span style="background:{acc}"></span><span style="background:{"#007AFF" if bg!=INK else "#0A84FF"}"></span></div></div>'''
cells=(ui(PAPER,INK,V,"#5F6875","Paper · Verdigris vs iOS blue")+ui(CARD,INK,V,"#5F6875","Card · Verdigris vs iOS blue")+
       "".join(ui(INK,PAPER,v,"#9AA3AE",f"Ink · {k} {v} vs iOS blue") for k,v in alts.items()))
html=f'''<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;width:1800px;height:640px;background:#fff;font-family:-apple-system}}
.wrap{{display:grid;grid-template-columns:repeat(6,1fr);gap:16px;padding:24px}}
.ph{{border-radius:18px;padding:20px;height:540px;box-sizing:border-box;position:relative;box-shadow:inset 0 0 0 1px rgba(17,20,24,.1)}}
.lbl{{font-size:12px;letter-spacing:.06em;text-transform:uppercase;margin-bottom:18px}}
.btn{{color:#fff;font-weight:600;font-size:17px;border-radius:12px;padding:14px;text-align:center}}
.lnk{{font-size:17px;margin:18px 0;font-weight:500}}
.bar{{height:6px;border-radius:3px;background:rgba(127,127,127,.25);overflow:hidden}} .bar div{{height:100%}}
.tab{{width:3px;height:28px;margin:24px 0 0 50%}}
.sw{{position:absolute;bottom:20px;left:20px;right:20px;display:flex;gap:10px}} .sw span{{flex:1;height:64px;border-radius:12px}}
</style></head><body><div class="wrap">{cells}</div></body></html>'''
open(f"{W}/accent.html","w").write(html)
subprocess.run(["/bin/zsh",f"{S}/render.sh",f"{W}/accent.html","1800","640",f"{W}/accent.png"],check=True); print("ok")
