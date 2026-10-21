import sys,math,json,os,collections; sys.path.insert(0,'/tmp/gunwork')
import numpy as np, bpy, bmesh
from mathutils import Vector, Matrix
import stf_lib as L, stf_pose as SP
OUT='/tmp/gunwork/stf_out'; os.makedirs(OUT,exist_ok=True)
BLADE=22
r=L.load()
src_bones=[b for b in r.arm.data.bones if b.use_deform]
NAMES=[b.name for b in src_bones]
PARENT={'root.x':None,
 'thigh_stretch.%s':'root.x','leg_stretch.%s':'thigh_stretch.%s','foot.%s':'leg_stretch.%s','toes_01.%s':'foot.%s',
 'thigh_twist.%s':'thigh_stretch.%s','leg_twist.%s':'leg_stretch.%s',
 'spine_01.x':'root.x','spine_02.x':'spine_01.x','spine_03.x':'spine_02.x','neck.x':'spine_03.x','head.x':'neck.x',
 'shoulder.%s':'spine_03.x','arm_stretch.%s':'shoulder.%s','c_arm_twist_offset.%s':'arm_stretch.%s',
 'forearm_stretch.%s':'arm_stretch.%s','forearm_twist.%s':'forearm_stretch.%s','hand.%s':'forearm_stretch.%s'}
for s in 'lr':
    for f in ('pinky','ring','middle','index'):
        PARENT[f'c_{f}1_base.%s']=f'hand.%s'; PARENT[f'{f}1.%s']=f'c_{f}1_base.%s'; PARENT[f'c_{f}2.%s']=f'{f}1.%s'; PARENT[f'c_{f}3.%s']=f'c_{f}2.%s'
    PARENT['thumb1.%s']='hand.%s'; PARENT['c_thumb2.%s']='thumb1.%s'; PARENT['c_thumb3.%s']='c_thumb2.%s'
def parent_of(n):
    for k,v in PARENT.items():
        if k==n: return v
        if '%s' in k and n.endswith(('.l','.r')) and k%n[-1]==n: return (v%n[-1]) if v and '%s' in v else v
    raise KeyError(n)
P={n:parent_of(n) for n in NAMES}
missing=[n for n in NAMES if n not in P]; print('bones',len(NAMES),'missing',missing)
# ---- new armature in operator space
bpy.ops.object.select_all(action='DESELECT')
ad=bpy.data.armatures.new('STFRig'); arm=bpy.data.objects.new('STFRig',ad); bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
Rz=np.diag([-1,-1,1.0])
eb={}
for b in src_bones:
    e=ad.edit_bones.new(b.name); h,t=L.tf(np.array(b.head_local)),L.tf(np.array(b.tail_local))
    if np.linalg.norm(t-h)<0.3: t=h+np.array([0,0,0.5])
    e.head=Vector(h); e.tail=Vector(t)
    xa=Rz@(np.array(b.matrix_local.to_3x3())@np.array([1,0,0.0])); e.align_roll(Vector(xa))
    e.use_deform=True; eb[b.name]=e
for n in NAMES:
    if P[n]: eb[n].parent=eb[P[n]]; eb[n].use_connect=False
bpy.ops.object.mode_set(mode='OBJECT')
# ---- meshes
def faceparts():
    fp={}
    for n in ('Object_0','Object_1','Object_2'):
        d=r.obj[n]; me=d['o'].data; co=d['co']; cl={}
        for pi,p in enumerate(me.polygons):
            mn=me.materials[p.material_index].name
            if n=='Object_0': k='head' if mn.startswith('Head') else 'body'
            elif n=='Object_1': k='gear'
            else:
                k='glass' if mn.startswith('SunGla') else ('nvg' if (lambda c:(c[1]>18.2 or (c[1]>13.5 and c[2]>181.5)))(co[list(p.vertices)].mean(0)) else 'helm')
            cl.setdefault(k,[]).append(pi)
        fp[n]=cl
    return fp
FP=faceparts()
WHITE=bpy.data.images.new('white4',4,4); WHITE.pixels=[1.0]*64; WHITE.pack()
def white_mat(name,rgba=(1,1,1,1)):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; b=nt.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value=rgba; b.inputs['Roughness'].default_value=0.85
    if rgba[3]<1: b.inputs['Alpha'].default_value=rgba[3]
    t=nt.nodes.new('ShaderNodeTexImage'); t.image=WHITE; nt.links.new(t.outputs['Color'],b.inputs['Base Color'])
    return m
exec(open('/tmp/gunwork/stf_export.py').read().split('def loop_normals')[1].split('def make_part')[0].join(['def loop_normals','']))
mats={k:white_mat(k) for k in ('head','body','gear','helm','nvg')}; mats['glass']=white_mat('glass',(0.04,0.04,0.05,0.8))
def make_part(objname,part):
    srco=r.obj[objname]['o']; src=srco.data; keep=set(FP[objname].get(part,[]))
    if not keep: return None
    me=src.copy(); me.vertices.foreach_set('co',r.obj[objname]['co'].reshape(-1)); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES')
    dv=[v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm,geom=dv,context='VERTS')
    dl=bm.verts.layers.deform.verify(); gi={g.name:g.index for g in srco.vertex_groups}; ri=gi.get('root.x',len(gi))
    for v in bm.verts:
        dv=v[dl]; tot=sum(dv.values())
        if tot>1.0001:
            for k in list(dv.keys()): dv[k]=dv[k]/tot
    m2=bpy.data.meshes.new(part); bm.to_mesh(m2); bm.free()
    try: m2.free_normals_split()
    except Exception: pass
    pass
    m2.materials.clear(); m2.materials.append(mats[part])
    for p in m2.polygons: p.use_smooth=True
    try: m2.normals_split_custom_set([tuple(x) for x in loop_normals(m2)])
    except Exception as e: print('normals',e)
    ob=bpy.data.objects.new(part+'_STF',m2); bpy.context.collection.objects.link(ob)
    for g in srco.vertex_groups: ob.vertex_groups.new(name=g.name)
    if 'root.x' not in ob.vertex_groups: ob.vertex_groups.new(name='root.x')
    ob.parent=arm; md=ob.modifiers.new('Armature','ARMATURE'); md.object=arm
    print(part,len(m2.vertices),'verts, groups',len(ob.vertex_groups))
    return ob
names=[]
for part,on in (('head','Object_0'),('body','Object_0'),('gear','Object_1'),('helm','Object_2'),('nvg','Object_2'),('glass','Object_2')):
    ob=make_part(on,part)
    if ob: names.append(ob.name)
bpy.ops.object.select_all(action='DESELECT')
for n in names+['STFRig']: bpy.data.objects[n].select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.export_scene.gltf(filepath=f'{OUT}/stf_rig.glb',export_format='GLB',export_yup=True,export_apply=False,use_selection=True,export_materials='EXPORT',export_image_format='JPEG',export_cameras=False,export_lights=False,export_skins=True,export_animations=False,export_all_influences=False)
print('exported',os.path.getsize(f'{OUT}/stf_rig.glb')//1024,'KB')
# ---- poses
C=np.array([[1,0,0],[0,0,1],[0,-1,0]],float)
def quat(R):
    m=R; t=m[0,0]+m[1,1]+m[2,2]
    if t>0: s=math.sqrt(t+1)*2; w=s/4; x=(m[2,1]-m[1,2])/s; y=(m[0,2]-m[2,0])/s; z=(m[1,0]-m[0,1])/s
    elif m[0,0]>m[1,1] and m[0,0]>m[2,2]: s=math.sqrt(1+m[0,0]-m[1,1]-m[2,2])*2; w=(m[2,1]-m[1,2])/s; x=s/4; y=(m[0,1]+m[1,0])/s; z=(m[0,2]+m[2,0])/s
    elif m[1,1]>m[2,2]: s=math.sqrt(1+m[1,1]-m[0,0]-m[2,2])*2; w=(m[0,2]-m[2,0])/s; x=(m[0,1]+m[1,0])/s; y=s/4; z=(m[1,2]+m[2,1])/s
    else: s=math.sqrt(1+m[2,2]-m[0,0]-m[1,1])*2; w=(m[1,0]-m[0,1])/s; x=(m[0,2]+m[2,0])/s; y=(m[1,2]+m[2,1])/s; z=s/4
    q=np.array([x,y,z,w]); return (q/np.linalg.norm(q)).tolist()
poses={}
for gid in SP.LEN:
    Ts,hold,G,(iR,iL)=SP.solve(r,gid,blade=BLADE,verbose=False)
    d={}
    for g,t in Ts.items():
        if g in NAMES: d[g]=quat(C@t.R@C.T)+(C@t(r.joint[g][0])).tolist()
    d['head.x']=[0,0,0,1]+(C@r.joint['head.x'][0]).tolist()
    poses[gid]=dict(al=hold['al'],phi=hold['phi'],pos=hold['pos'],bones=d,err=[iR['err'],iL['err']])
    print(gid,'err %.1f %.1f'%(iR['err'],iL['err']),len(d))
json.dump(poses,open(f'{OUT}/stfpose.json','w'))
