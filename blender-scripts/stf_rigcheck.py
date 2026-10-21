import sys,json,struct,math; sys.path.insert(0,'/tmp/gunwork')
import numpy as np
def load(path):
    d=open(path,'rb').read(); off=12; js=None; bn=b''
    while off<len(d):
        l,t=struct.unpack('<II',d[off:off+8]); c=d[off+8:off+8+l]
        if t==0x4E4F534A: js=json.loads(c)
        elif t==0x004E4942: bn=c
        off+=8+((l+3)&~3)
    return js,bn
def acc(j,bn,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',0)
    isz=np.dtype(dt).itemsize
    if st and st!=isz*n:
        raw=np.frombuffer(bn,dtype='u1',count=a['count']*st,offset=off).reshape(a['count'],st)[:,:isz*n].copy()
        return raw.view(dt).reshape(a['count'],n)
    return np.frombuffer(bn,dtype=dt,count=a['count']*n,offset=off).reshape(a['count'],n).astype(float if dt!='u1' else float)
def qmat(q):
    x,y,z,w=q; return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def mq(R):
    from stf_rig_q import quat
    return quat(R)
def qmul(a,b):
    x1,y1,z1,w1=a; x2,y2,z2,w2=b
    return np.array([w1*x2+x1*w2+y1*z2-z1*y2,w1*y2-x1*z2+y1*w2+z1*x2,w1*z2+x1*y2-y1*x2+z1*w2,w1*w2-x1*x2-y1*y2-z1*z2])
def qinv(q): return np.array([-q[0],-q[1],-q[2],q[3]])/np.dot(q,q)
def local(n):
    M=np.eye(4)
    if 'matrix' in n: M=np.array(n['matrix']).reshape(4,4).T
    else:
        R=qmat(n.get('rotation',[0,0,0,1])); S=np.array(n.get('scale',[1,1,1])); M[:3,:3]=R*S; M[:3,3]=n.get('translation',[0,0,0])
    return M
j,bn=load(sys.argv[1] if len(sys.argv)>1 else '/tmp/gunwork/stf_out/stf_rig.glb')
nodes=j['nodes']; par={}
for i,n in enumerate(nodes):
    for c in n.get('children',[]): par[c]=i
print('nodes',len(nodes),'skins',len(j['skins']),[len(s['joints']) for s in j['skins']])
byname={n.get('name'):i for i,n in enumerate(nodes)}
def world(i,loc):
    M=loc[i]; 
    while i in par: i=par[i]; M=loc[i]@M
    return M
