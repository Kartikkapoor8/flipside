import math, os, subprocess
S=os.path.dirname(os.path.abspath(__file__)); W=os.path.join(S,"work"); os.makedirs(W,exist_ok=True)
PAPER,CARD,INK,SLATE,MUTED,ACC,ACCD="#F1F2F4","#FFFFFF","#111418","#1A1E24","#5F6875","#0E6B5E","#46A98F"
def path_perp(theta,T,r,width,box=100):  # current: perpendicular feet
    th=math.radians(theta); s,c=math.sin(th),math.cos(th); Tc=T-2*r; Lc=(width-2*r)/(2*s)
    h=Lc*c+Tc*s+2*r; cx=box/2; top=(box-h)/2+r
    d=(-s,c); n=(c,s); Po=(cx,top); Fo=(cx+Lc*d[0],top+Lc*d[1]); Fi=(Fo[0]+Tc*n[0],Fo[1]+Tc*n[1]); Pi=(cx,top+Tc/s)
    m=lambda p:(2*cx-p[0],p[1]); pts=[Po,Fo,Fi,Pi,m(Fi),m(Fo)]
    return "M"+" L".join(f"{x:.2f} {y:.2f}" for x,y in pts)+" Z", cx, top-r, h
def path_flat(theta,T,r,width,box=100,cy=None):  # revised: horizontal feet on a ground line
    th=math.radians(theta); t=math.tan(th); s=math.sin(th); Tc=T-2*r
    rise=(width-2*r)/(2*t); h=rise+2*r; cx=box/2; top=(box-h)/2+r if cy is None else cy-h/2+r
    G=top+rise; Pi=(cx,top+Tc/s); xo=cx-rise*t; xi=cx-(G-Pi[1])*t
    pts=[(cx,top),(xo,G),(xi,G),Pi,(2*cx-xi,G),(2*cx-xo,G)]
    return "M"+" L".join(f"{x:.2f} {y:.2f}" for x,y in pts)+" Z", cx, top-r, h, G+r
def body(d,cx,ink,acc,r,uid,extra=""):
    return (f'<defs><clipPath id="{uid}"><rect x="0" y="0" width="{cx}" height="100"/></clipPath></defs>'
            f'<path d="{d}" fill="{ink}" stroke="{ink}" stroke-width="{2*r}" stroke-linejoin="round"/>'
            f'<path d="{d}" fill="{acc}" stroke="{acc}" stroke-width="{2*r}" stroke-linejoin="round" clip-path="url(#{uid})"/>'+extra)
def svg(inner,bg=None,box=100):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {box} {box}">'+(f'<rect width="{box}" height="{box}" fill="{bg}"/>' if bg else "")+inner+'</svg>'
CANDS=[]
# a) current
d,cx,vt,h=path_perp(36,16,4,72); CANDS.append(("a · current θ36 perpendicular feet", lambda ink,acc,u,bg=None: svg(body(d,cx,ink,acc,4,u),bg)))
# b) θ38 flat feet
d2,cx2,vt2,h2,g2=path_flat(38,16,4,76); CANDS.append(("b · θ38 flat feet", lambda ink,acc,u,bg=None: svg(body(d2,cx2,ink,acc,4,u),bg)))
# c) θ42 flat feet thicker
d3,cx3,vt3,h3,g3=path_flat(42,18,4.5,78); CANDS.append(("c · θ42 T18 flat feet", lambda ink,acc,u,bg=None: svg(body(d3,cx3,ink,acc,4.5,u),bg)))
# d) θ38 flat feet + ground bar in the mark
def d_fn(ink,acc,u,bg=None):
    bar=f'<rect x="{cx2-76/2-5:.2f}" y="{g2-0.5:.2f}" width="86" height="3.2" rx="1.6" fill="{MUTED if ink==INK else "#9AA3AE"}"/>'
    return svg(body(d2,cx2,ink,acc,4,u,bar),bg)
CANDS.append(("d · θ38 flat feet + table bar",d_fn))
# e) θ38 flat feet + table plane (tonal band) — icon-only cue, shown here on bg
def e_fn(ink,acc,u,bg=None):
    table=CARD if bg==PAPER else (SLATE if bg==INK else None)
    band=f'<rect x="0" y="{g2:.2f}" width="100" height="{100-g2:.2f}" fill="{table}"/>' if table else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'+(f'<rect width="100" height="100" fill="{bg}"/>' if bg else "")+band+body(d2,cx2,ink,acc,4,u)+'</svg>'
CANDS.append(("e · θ38 flat feet + table plane (icon bg only)",e_fn))
def cell(sv,px,radius=0): return f'<div style="width:{px}px;height:{px}px;border-radius:{radius}px;overflow:hidden;flex:none">{sv.replace("<svg ",f"<svg style=%cwidth:{px}px;height:{px}px%c "%(39,39),1)}</div>'
rows=""
for i,(name,fn) in enumerate(CANDS):
    L=lambda px,rad=0: cell(fn(INK,ACC,f"l{i}{px}"),px,rad); D=lambda px,rad=0: cell(fn(PAPER,ACCD,f"d{i}{px}"),px,rad)
    icoL=lambda px: cell(fn(INK,ACC,f"il{i}{px}",PAPER),px,round(px*0.2237)); icoD=lambda px: cell(fn(PAPER,ACCD,f"id{i}{px}",INK),px,round(px*0.2237))
    rows+=f'''<div class="r"><div class="n">{name}</div>
    <div class="g paper">{L(16)}{L(24)}{L(32)}{L(60)}</div><div class="g ink">{D(16)}{D(24)}{D(32)}{D(60)}</div>
    <div class="g">{icoL(29)}{icoL(60)}{icoL(120)}{icoD(60)}{icoD(120)}</div><div class="g">{icoL(256)}</div></div>'''
html=f'''<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;width:1800px;height:1720px;background:#fff;font-family:-apple-system}}
.r{{display:flex;align-items:center;gap:20px;padding:12px 24px;border-bottom:1px solid #e5e7eb}} .n{{width:250px;font-size:13px;color:#5F6875}}
.g{{display:flex;align-items:flex-end;gap:14px;padding:12px;border-radius:12px}} .paper{{background:{PAPER}}} .ink{{background:{INK}}}
</style></head><body>{rows}</body></html>'''
open(f"{W}/explore2.html","w").write(html)
subprocess.run(["/bin/zsh",f"{S}/render.sh",f"{W}/explore2.html","1800","1720",f"{W}/explore2.png"],check=True); print("ok")
