import math, os, subprocess
S=os.path.abspath("."); W=os.path.join(S,"work")
PAPER,INK,ACC,ACCD="#F1F2F4","#111418","#0E6B5E","#3E9C85"
def project(p,yaw,pitch):
    x,y,z=p; cy,sy=math.cos(yaw),math.sin(yaw); x1=x*cy+z*sy; z1=-x*sy+z*cy
    cp,sp=math.cos(pitch),math.sin(pitch); y2=y*cp-z1*sp
    return (x1,-y2)
def faces(tn,tf,yaw,pitch,slope=0.47,ridge=1.0,fill=76,box=100,r=3.0):
    # ridge along z at height H; near face leans toward -x by tilt tn; far face leans toward +x by tilt tf; both reach y=0
    H=slope*math.cos(math.radians(tn))  # ridge height set by the near half
    Wn=slope*math.sin(math.radians(tn))
    # far half: same slope length, reclined: its foot lower? keep both feet on the table: far half slope length is fixed, so with larger tilt its ridge would be lower.
    # physical: both halves share the ridge; if tilts differ the ridge height is min over both -> use the far half to set H and let the near half's foot float? No: keep table flat, both halves same length -> tilts must satisfy cos(tn)=cos(tf). So model the far half as reclined by rotating around the ridge and lifting: presenter half rests on a hand/edge. Simplify: far half length shorter visually by projecting to H.
    Wf=H*math.tan(math.radians(tf))
    near=[(0,H,-ridge/2),(0,H,ridge/2),(-Wn,0,ridge/2),(-Wn,0,-ridge/2)]
    far=[(0,H,ridge/2),(0,H,-ridge/2),(Wf,0,-ridge/2),(Wf,0,ridge/2)]
    y,p=math.radians(yaw),math.radians(pitch)
    N=[project(q,y,p) for q in near]; F=[project(q,y,p) for q in far]
    xs=[q[0] for q in N+F]; ys=[q[1] for q in N+F]; w=max(xs)-min(xs); h=max(ys)-min(ys); sc=(fill-2*r)/max(w,h)
    ox=box/2-(min(xs)+w/2)*sc; oy=box/2-(min(ys)+h/2)*sc
    f=lambda pts:[(q[0]*sc+ox,q[1]*sc+oy) for q in pts]
    return f(N),f(F)
def poly(pts): return "M"+" L".join(f"{x:.2f} {y:.2f}" for x,y in pts)+" Z"
def tsvg(tn,tf,yaw,pitch,ink,acc,bg=None,r=3.0):
    N,F=faces(tn,tf,yaw,pitch,r=r)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'+(f'<rect width="100" height="100" fill="{bg}"/>' if bg else "")+
            f'<path d="{poly(F)}" fill="{ink}" stroke="{ink}" stroke-width="{2*r}" stroke-linejoin="round"/>'
            f'<path d="{poly(N)}" fill="{acc}" stroke="{acc}" stroke-width="{2*r}" stroke-linejoin="round"/></svg>')
def cell(sv,px,radius=0): return f'<div style="width:{px}px;height:{px}px;border-radius:{radius}px;overflow:hidden;flex:none">{sv.replace("<svg ",f"<svg style=%cwidth:{px}px;height:{px}px%c "%(39,39),1)}</div>'
rows=""
for tn,tf in ((18,58),(24,64)):
    for pitch in (32,42):
        for yaw in (90,78,66):
            kw=dict(tn=tn,tf=tf,yaw=yaw,pitch=pitch)
            L=lambda px: cell(tsvg(ink=INK,acc=ACC,**kw),px); D=lambda px: cell(tsvg(ink=PAPER,acc=ACCD,**kw),px)
            icoL=lambda px: cell(tsvg(ink=INK,acc=ACC,bg=PAPER,**kw),px,round(px*0.2237)); icoD=lambda px: cell(tsvg(ink=PAPER,acc=ACCD,bg=INK,**kw),px,round(px*0.2237))
            rows+=f'''<div class="r"><div class="n">near {tn}° · far {tf}° · pitch {pitch} · yaw {yaw}</div>
            <div class="g paper">{L(16)}{L(24)}{L(32)}{L(60)}</div><div class="g ink">{D(16)}{D(24)}{D(32)}{D(60)}</div>
            <div class="g">{icoL(29)}{icoL(60)}{icoL(120)}{icoD(60)}{icoD(120)}</div><div class="g">{icoL(170)}</div></div>'''
html=f'''<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;width:1750px;height:2330px;background:#fff;font-family:-apple-system}}
.r{{display:flex;align-items:center;gap:20px;padding:3px 24px;border-bottom:1px solid #e5e7eb}} .n{{width:210px;font-size:12px;color:#5F6875}}
.g{{display:flex;align-items:flex-end;gap:14px;padding:8px;border-radius:12px}} .paper{{background:{PAPER}}} .ink{{background:{INK}}}
</style></head><body>{rows}</body></html>'''
open(f"{W}/explore6.html","w").write(html)
subprocess.run(["/bin/zsh",f"{S}/render.sh",f"{W}/explore6.html","1750","2330",f"{W}/explore6.png"],check=True); print("ok")
