import sys,json,math; sys.path.insert(0,'/tmp/gunwork')
exec(open('/tmp/gunwork/stf_rigcheck.py').read().split("j,bn=load")[0])
import numpy as np
import stf_lib as L, stf_pose as SP
j,bn=load('/tmp/gunwork/stf_out/stf_rig.glb')
poses=json.load(open('/tmp/gunwork/stf_out/stfpose.json'))
nodes=j['nodes']; par={}
for i,n in enumerate(nodes):
    for c in n.get('children',[]): par[c]=i
skin=j['skins'][0]; J=skin['joints']; IBM=acc(j,bn,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
# --- MXRig port
loc0=[local(n) for n in nodes]
def rel_world(i,loc,root=None):
    M=loc[i]
    while i in par: i=par[i]; M=loc[i]@M
    return M
def rotof(M):
    R=M[:3,:3]/np.linalg.norm(M[:3,:3],axis=0); return R
rw={i:rotof(rel_world(i,loc0)) for i in J}
def apply(delta,pos=None):
    pos=pos or {}
    loc=list(loc0); cur={}; cpos={}
    order=sorted(J,key=lambda i:len(list(iter_par(i))))
    for i in order:
        parent=par.get(i); 
        pW=cur[parent] if parent in cur else (rotof(rel_world(parent,loc0)) if parent is not None else np.eye(3))
        rl=rotof(loc0[i]); nm=nodes[i]['name']
        tw=qmat(delta[nm])@rw[i] if nm in delta else pW@rl
        cur[i]=tw
        M=loc0[i].copy(); S=np.linalg.norm(loc0[i][:3,:3],axis=0)
        M[:3,:3]=(pW.T@tw)*S
        pp=cpos[parent] if parent in cpos else (rel_world(parent,loc0)[:3,3] if parent is not None else np.zeros(3))
        if nm in pos: M[:3,3]=pW.T@(pos[nm]-pp)
        loc[i]=M
        cpos[i]=pp+pW@M[:3,3]
    return loc
def iter_par(i):
    while i in par: i=par[i]; yield i
def run(gid):
    p=poses[gid]; delta={k:np.array(v[:4]) for k,v in p['bones'].items()}; pos={k:np.array(v[4:]) for k,v in p['bones'].items()}
    loc=apply(delta,pos)
    jm=[np.linalg.inv(rel_world(0,loc)*0+np.eye(4))@rel_world(J[k],loc)@IBM[k] for k in range(len(J))]
    return jm
r=L.load()
for _n in ('Object_0','Object_1','Object_2'):
    _W=r.obj[_n]['W']; r.obj[_n]['W']=_W/np.maximum(_W.sum(1,keepdims=True),1e-9)
key={}
for n in ('Object_0','Object_1'):
    for vi,c in enumerate(r.obj[n]['co']): key[(n,tuple(np.round(c,2)))]=vi
for gid in ('m4','pistol','awp'):
    Ts,hold,G,_=SP.solve(r,gid,blade=22,verbose=False)
    jm=run(gid); worst=0; cnt=0
    for ni,node in enumerate(nodes):
        if 'mesh' not in node: continue
        prim=j['meshes'][node['mesh']]['primitives'][0]
        pos=acc(j,bn,prim['attributes']['POSITION']); jj=acc(j,bn,prim['attributes']['JOINTS_0']).astype(int); ww=acc(j,bn,prim['attributes']['WEIGHTS_0'])
        if node['name'] not in ('body_STF','gear_STF','head_STF'): continue
        on='Object_1' if node['name']=='gear_STF' else 'Object_0'
        ref=L.skin(r,on,Ts)
        for v in range(0,len(pos),5):
            M=sum(ww[v,k]*jm[jj[v,k]] for k in range(4)); M=M/ max(ww[v].sum(),1e-9)*1
            p=(M@np.append(pos[v],1))[:3]
            # gltf->blender
            pb=np.array([p[0],-p[2],p[1]]); b0=np.array([pos[v][0],-pos[v][2],pos[v][1]])
            vi=key.get((on,tuple(np.round(b0,2))))
            if vi is None: continue
            e=np.linalg.norm(pb-ref[vi]); worst=max(worst,e); cnt+=1
            if node['name']=='head_STF' and e>1: pass
        print(gid,node['name'],'checked',cnt,'worst err cm %.2f'%worst)
print('---- diagnostics')
Ts,hold,G,_=SP.solve(r,'m4',blade=22,verbose=False)
for label,delta in (('rest',{}),('m4',{k:np.array(v[:4]) for k,v in poses['m4']['bones'].items()})):
    loc=apply(delta,{k:np.array(v[4:]) for k,v in poses['m4']['bones'].items()} if label!='rest' else {})
    jm=[rel_world(J[k],loc)@IBM[k] for k in range(len(J))]
    errs={}
    node=[n for n in nodes if n.get('name')=='body_STF'][0]
    prim=j['meshes'][node['mesh']]['primitives'][0]
    pos=acc(j,bn,prim['attributes']['POSITION']); jj=acc(j,bn,prim['attributes']['JOINTS_0']).astype(int); ww=acc(j,bn,prim['attributes']['WEIGHTS_0'])
    ref=L.skin(r,'Object_0',Ts if label!='rest' else {})
    for v in range(len(pos)):
        M=sum(ww[v,k]*jm[jj[v,k]] for k in range(4))/max(ww[v].sum(),1e-9)
        p=(M@np.append(pos[v],1))[:3]; pb=np.array([p[0],-p[2],p[1]]); b0=np.array([pos[v][0],-pos[v][2],pos[v][1]])
        vi=key.get(('Object_0',tuple(np.round(b0,2))))
        if vi is None: continue
        e=np.linalg.norm(pb-ref[vi]); b=nodes[J[jj[v,np.argmax(ww[v])]]]['name']
        errs.setdefault(b,[]).append(e)
    print(label,sorted(((round(max(v),1),k) for k,v in errs.items()),reverse=True)[:12])
print('---- bone matrices')
loc=apply({k:np.array(v[:4]) for k,v in poses['m4']['bones'].items()},{k:np.array(v[4:]) for k,v in poses['m4']['bones'].items()})
C=np.array([[1,0,0],[0,0,1],[0,-1,0]],float)
bad=[]
for k in range(len(J)):
    nm=nodes[J[k]]['name']
    if nm not in Ts: continue
    M=rel_world(J[k],loc)@IBM[k]
    Rb=Ts[nm].R; tb=Ts[nm].t
    Rg=C@Rb@C.T; tg=C@tb
    eR=np.abs(M[:3,:3]-Rg).max(); et=np.linalg.norm(M[:3,3]-tg)
    bad.append((round(et,2),round(eR,3),nm))
print(sorted(bad,reverse=True)[:14])
print('---- weights'); byname={n.get('name'):i for i,n in enumerate(nodes)}
d=r.obj['Object_0']; W=d['W']; names=d['names']
print('groups',len(names),'not bones',[n for n in names if n not in byname])
tot=W.sum(1); srt=-np.sort(-W,axis=1); top4=srt[:,:4].sum(1)
print('verts',len(W),'tot<0.99',(tot<0.99).sum(),'tot>1.01',(tot>1.01).sum(),'lost>0.05',((tot-top4)>0.05).sum(),'max lost',(tot-top4).max())
print('nonzero per vertex max',(W>0).sum(1).max())
print('---- worst vertex')
loc=apply({k:np.array(v[:4]) for k,v in poses['m4']['bones'].items()},{k:np.array(v[4:]) for k,v in poses['m4']['bones'].items()})
jm=[rel_world(J[k],loc)@IBM[k] for k in range(len(J))]
node=[n for n in nodes if n.get('name')=='body_STF'][0]
prim=j['meshes'][node['mesh']]['primitives'][0]
pos=acc(j,bn,prim['attributes']['POSITION']); jj=acc(j,bn,prim['attributes']['JOINTS_0']).astype(int); ww=acc(j,bn,prim['attributes']['WEIGHTS_0'])
ref=L.skin(r,'Object_0',Ts)
res=[]
for v in range(len(pos)):
    M=sum(ww[v,k]*jm[jj[v,k]] for k in range(4))
    p=(M@np.append(pos[v],1))[:3]; pb=np.array([p[0],-p[2],p[1]]); b0=np.array([pos[v][0],-pos[v][2],pos[v][1]])
    vi=key.get(('Object_0',tuple(np.round(b0,2))))
    if vi is None: continue
    res.append((np.linalg.norm(pb-ref[vi]),v,vi))
res.sort(reverse=True)
for e,v,vi in res[:4]:
    print('err %.1f'%e,'glb',[(nodes[J[jj[v,k]]]['name'],round(ww[v,k],2)) for k in range(4)],'np',[(names[g],round(float(W[vi,g]),2)) for g in np.argsort(-W[vi])[:5]])
print('n',len(res),'median',np.median([x[0] for x in res]))
es=np.array([x[0] for x in res]); print('over0.3',(es>0.3).sum(),'over1',(es>1).sum(),'of',len(es))
for e,v,vi in res[:3]:
    print('err %.1f'%e,[(names[g],round(float(W[vi,g]),2)) for g in np.argsort(-W[vi])[:8]])
