"""Run in Blender 5.3 with the V6 scene loaded and an outputs directory in the current workspace."""

import bpy, random, math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

scene=bpy.context.scene
out=Path('outputs').resolve()
outer=bpy.data.collections['NONPLAY | World beyond battlefield']
dressing=bpy.data.collections.new('V7 | Processional court')
outer.children.link(dressing)
rng=random.Random(733)
mats=bpy.data.materials
stone=mats['cathedral cut stone']
dark=mats['outer | deep recessed masonry']
floor=mats['cracked slate flagstone']
bronze=mats['outer | tarnished bronze relief']

# Low, worn sanctuary paving links the board's central aisle to the rose bay.
def slab(name,position,size,material,angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=position)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    uv=obj.data.uv_layers.active
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda i: abs(face.normal[i]))
        u,v=[i for i in range(3) if i!=axis]
        for loop in face.loop_indices:
            point=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(point[u]/1.5,point[v]/1.5)
    obj.rotation_euler.z=angle
    for collection in tuple(obj.users_collection):
        collection.objects.unlink(obj)
    dressing.objects.link(obj)
    obj.data.materials.append(material)
    obj['collision_role']='visual_only'
    bevel=obj.modifiers.new('Worn edges','BEVEL')
    bevel.width,bevel.segments=.028,2
    return obj

for row in range(7):
    y=7.45+row*.79
    for col in range(-4,5):
        x=col*.84+(.16 if row%2 else -.16)
        if abs(col)>2 and rng.random()<.21:
            continue
        slab('Court | worn paving',(x,y,.144+rng.uniform(-.012,.012)),
             (.80-rng.uniform(0,.038),.745,.115),stone if (abs(col)==0 and row in (0,1,4,5)) else floor,rng.uniform(-.018,.018))
for side in (-1,1):
    for row in range(10):
        y=7.46+row*.56
        slab('Court | broken curb',(side*3.96,y,.22),(.27,.52,.23),stone,rng.uniform(-.03,.03))
    for row in range(4):
        y=8.06+row*1.17
        slab('Court | burial ledger',(side*(4.76+row%2*.13),y,.19),(.84,.91,.18),dark,rng.uniform(-.16,.16))
        slab('Court | inset memorial brass',(side*(4.76+row%2*.13),y,.286),(.40,.055,.015),bronze)
    for n in range(15):
        y=rng.uniform(7.32,12.91)
        x=side*rng.uniform(4.1,6.4)
        size=rng.uniform(.12,.43)
        slab('Court | fallen facing',(x,y,.14+size*.19),(size,size*.7,size*.43),stone,rng.uniform(-math.pi,math.pi))

# Submerged stone steps and gravel connect the foreground threshold to the nave.
for step,(y,top) in enumerate(((-7.28,-.15),(-7.67,-.30),(-8.04,-.44))):
    for i in range(-2,3):
        slab('Threshold | broken stair',(i*.68,y,top-.13),(.65,.44,.26),floor,rng.uniform(-.025,.025))
for side in (-1,1):
    for i in range(14):
        y=rng.uniform(-6.65,5.9)
        x=side*rng.uniform(7.02,7.63)
        size=rng.uniform(.14,.30)
        slab('Threshold | fallen nave stone',(x,y,-.25+rng.uniform(-.06,.06)),(size,size*.8,size*.55),dark,rng.uniform(-3,3))

# Offset the existing warm rim to graze the stone and separate the rear court.
light=bpy.data.objects['warm sanctuary rim']
light.location=(-5.5,8.6,6.8)
light.rotation_euler=(Vector((0,10,1.0))-light.location).to_track_quat('-Z','Y').to_euler()
light.data.energy=720
scene['Hollowmark build']='V7 | Processional Court'
scene.render.resolution_percentage=75
scene.render.filepath='//Hollowmark Last Benediction V7 Preview.png'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Hollowmark Last Benediction V7.blend'))
bpy.ops.render.render(write_still=True)


