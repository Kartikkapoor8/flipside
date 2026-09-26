import math, os, subprocess
S=os.path.dirname(os.path.abspath(__file__)); W=os.path.join(S,"work")
PAPER,CARD,INK,SLATE,MUTED,ACC,ACCD="#F1F2F4","#FFFFFF","#111418","#1A1E24","#5F6875","#0E6B5E","#46A98F"
def project(p,yaw,pitch):
    x,y,z=p; cy,sy=math.cos(yaw),math.sin(yaw); x1=x*cy+z*sy; z1=-x*sy+z*cy
    cp,sp=math.cos(pitch),math.sin(pitch); y2=y*cp-z1*sp
    return (x1,-y2)
def tent_faces(theta_deg,slope=0.47,ridge=1.0,yaw=30,pitch=22,box=100,fill=76):
    th=math.radians(theta_deg); H=slope*math.cos(th); Wb=slope*math.sin(th); D=ridge
    L=[(0,H,-D/2),(0,H,D/2),(-Wb,0,D/2),(-Wb,0,-D/2)]   # audience face (near-left)
    R=[(0,H,D/2),(0,H,-D/2),(Wb,0,-D/2),(Wb,0,D/2)]     # presenter face (far-right)
    y,p=math.radians(yaw),math.radians(pitch)
    Lp=[project(q,y,p) for q in L]; Rp=[project(q,y,p) for q in R]
    allp=Lp+Rp; xs=[q[0] for q in allp]; ys=[q[1] for q in allp]
    w=max(xs)-min(xs); h=max(ys)-min(ys); s=fill/max(w,h)
    ox=box/2-(min(xs)+w/2)*s; oy=box/2-(min(ys)+h/2)*s
    f=lambda pts:[(q[0]*s+ox,q[1]*s+oy) for q in pts]
    return f(Lp),f(Rp)
def poly(pts): return "M"+" L".join(f"{x:.2f} {y:.2f}" for x,y in pts)+" Z"
def tent_svg(theta,yaw,pitch,ink,acc,r=2.5,bg=None,slope=0.47,ridge=1.0,gap=0):
    Lp,Rp=tent_faces(theta,slope,ridge,yaw,pitch)
    o=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'+(f'<rect width="100" height="100" fill="{bg}"/>' if bg else "")
    o+=f'<path d="{poly(Rp)}" fill="{ink}" stroke="{ink}" stroke-width="{2*r}" stroke-linejoin="round"/>'
    if gap and bg: o+=f'<path d="{poly(Lp)}" fill="none" stroke="{bg}" stroke-width="{2*r+gap}" stroke-linejoin="round"/>'
    o+=f'<path d="{poly(Lp)}" fill="{acc}" stroke="{acc}" stroke-width="{2*r}" stroke-linejoin="round"/></svg>'
    return o
def cell(sv,px,radius=0): return f'<div style="width:{px}px;height:{px}px;border-radius:{radius}px;overflow:hidden;flex:none">{sv.replace("<svg ",f"<svg style=%cwidth:{px}px;height:{px}px%c "%(39,39),1)}</div>'
CANDS=[("f · A-frame, tilt36, yaw30 pitch22",dict(theta=36,yaw=30,pitch=22)),
       ("g · tilt36, yaw40 pitch28",dict(theta=36,yaw=40,pitch=28)),
       ("h · tilt42, yaw25 pitch18",dict(theta=42,yaw=25,pitch=18)),
       ("i · tilt36, yaw18 pitch30 (more top)",dict(theta=36,yaw=18,pitch=30)),
       ("j · squarer halves (slope .6), yaw30 pitch22",dict(theta=36,yaw=30,pitch=22,slope=0.6,ridge=0.9)),
       ("k · f with ridge gap",dict(theta=36,yaw=30,pitch=22,gap=1.4))]
rows=""
for i,(name,kw) in enumerate(CANDS):
    L=lambda px: cell(tent_svg(ink=INK,acc=ACC,**kw),px); D=lambda px: cell(tent_svg(ink=PAPER,acc=ACCD,**kw),px)
    icoL=lambda px: cell(tent_svg(ink=INK,acc=ACC,bg=PAPER,**kw),px,round(px*0.2237)); icoD=lambda px: cell(tent_svg(ink=PAPER,acc=ACCD,bg=INK,**kw),px,round(px*0.2237))
    rows+=f'''<div class="r"><div class="n">{name}</div>
    <div class="g paper">{L(16)}{L(24)}{L(32)}{L(60)}</div><div class="g ink">{D(16)}{D(24)}{D(32)}{D(60)}</div>
    <div class="g">{icoL(29)}{icoL(60)}{icoL(120)}{icoD(60)}{icoD(120)}</div><div class="g">{icoL(256)}</div></div>'''
html=f'''<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;width:1800px;height:1900px;background:#fff;font-family:-apple-system}}
.r{{display:flex;align-items:center;gap:20px;padding:10px 24px;border-bottom:1px solid #e5e7eb}} .n{{width:250px;font-size:13px;color:#5F6875}}
.g{{display:flex;align-items:flex-end;gap:14px;padding:12px;border-radius:12px}} .paper{{background:{PAPER}}} .ink{{background:{INK}}}
</style></head><body>{rows}</body></html>'''
open(f"{W}/explore3.html","w").write(html)
subprocess.run(["/bin/zsh",f"{S}/render.sh",f"{W}/explore3.html","1800","1900",f"{W}/explore3.png"],check=True); print("ok")
