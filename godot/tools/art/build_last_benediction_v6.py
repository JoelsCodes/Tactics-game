"""Upgrade the textured V5.2 scene to Broken Rose in Blender 5.3.

From a workspace with an outputs directory:
    blender --background --factory-startup --disable-autoexec "outputs/Hollowmark Last Benediction V5.2 Textured.blend" --python-exit-code 1 --python godot/tools/art/build_last_benediction_v6.py

The input scene contains the packed Poly Haven CC0 assets and provenance.
Verified locally in Blender 5.3.0 with 121 cells and 15 packed maps.
The mesh-only GLB loaded in Godot 4.7.2 with 1,947 mesh instances and no collision objects.
"""

import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

scene = bpy.context.scene
outer = bpy.data.collections['NONPLAY | World beyond battlefield']
facade = bpy.data.collections.new('V6 | Bell towers and rose-window masonry')
outer.children.link(facade)
stone = bpy.data.materials['cathedral cut stone']
wall = bpy.data.materials['outer | pale rain-washed cathedral stone']
bronze = bpy.data.materials['outer | tarnished bronze relief']
rng = random.Random(612)
output = Path('outputs').resolve()

def place(obj, name, material):
    obj.name = name
    facade.objects.link(obj)
    obj['collision_role'] = 'visual_only'
    if material:
        obj.data.materials.append(material)
    return obj

def surface(obj, bevel):
    uv = obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda index: abs(normal[index]))
        i, j = [index for index in range(3) if index != axis]
        for loop in poly.loop_indices:
            p = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[i] / 1.8, p[j] / 1.8)
    if bevel:
        mod = obj.modifiers.new('Weathered arrises', 'BEVEL')
        mod.width, mod.segments = bevel, 2
        obj.modifiers.new('Masonry normals', 'WEIGHTED_NORMAL')

def extrude(name, outline, front, back, material=None, bevel=0):
    n = len(outline)
    vertices = [(x,y,z) for y in (front,back) for x,z in outline]
    faces = [tuple(range(n)), tuple(range(2*n-1,n-1,-1))]
    faces += [(i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()
    obj = place(bpy.data.objects.new(name,mesh),name,material)
    if material:
        surface(obj,bevel)
    return obj

def block(name,x,z,w,h,front,back,material=stone):
    return extrude(name,[(x-w/2,z-h/2),(x+w/2,z-h/2),(x+w/2,z+h/2),(x-w/2,z+h/2)],
                   front,back,material,.025)

def lancet_point(x,z,half,rise,side,t):
    # Circular Gothic shoulders meeting at the crown, with vertical spring tangents.
    radius = (half*half + rise*rise)/(2*half)
    angle = math.asin(rise/radius)
    return x+side*(half-radius+radius*math.cos(angle*t)), z+radius*math.sin(angle*t)

def arch(name,x,z,half,rise,thickness,front,back,steps,missing=()):
    for side in (-1,1):
        for i in range(steps):
            if (side,i) in missing:
                continue
            a,b=(i+.035)/steps,(i+.965)/steps
            inner=[lancet_point(x,z,half,rise,side,t) for t in (a,b)]
            outer_points=[lancet_point(x,z,half+thickness,rise+thickness*1.1,side,t) for t in (b,a)]
            outline=inner+outer_points
            if side==1:
                outline.reverse()
            extrude(name,outline,front+rng.uniform(-.017,.017),back,stone,.017)

def cut_window(tower,x,spring,bottom,half,rise):
    outline=[(x-half,bottom),(x+half,bottom)]
    outline += [lancet_point(x,spring,half,rise,1,i/10) for i in range(11)]
    outline += [lancet_point(x,spring,half,rise,-1,i/10) for i in range(9,-1,-1)]
    cutter=extrude('Temporary lancet cutter',outline,10.7,14.4)
    # Apply the cut before the original tower bevel.
    mod=tower.modifiers.new('Through-cut belfry', 'BOOLEAN')
    mod.operation='DIFFERENCE'
    mod.object=cutter
    tower.modifiers.move(len(tower.modifiers)-1,0)
    bpy.context.view_layer.objects.active=tower
    before=len(tower.data.vertices)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    assert len(tower.data.vertices)>before
    bpy.data.objects.remove(cutter,do_unlink=True)

for obj in list(outer.all_objects):
    if any(token in obj.name for token in ('shadowed bell opening','bell-tower lancet','V4 | tower facade stone')):
        bpy.data.objects.remove(obj,do_unlink=True)

for suffix, x, spring in (('',-10.7,5.48),('.001',10.7,6.25)):
    tower=bpy.data.objects['NONPLAY | ruined bell tower mass'+suffix]
    bottom=spring-1.24
    cut_window(tower,x,spring,bottom,.56,.94)
    arch('Belfry | dressed lancet voussoir',x,spring,.57,.94,.22,11.18,11.54,6)
    for side in (-1,1):
        for row in range(4):
            block('Belfry | jamb course',x+side*.67,bottom+.15+row*.31,.21,.288,11.19,11.53)
        for row in range(9):
            width=.27 if row%2 else .42
            block('Belfry | corner quoin',x+side*(1.22-width/2),.48+row*.39,width,.35,11.24,11.62)
    block('Belfry | projecting sill',x,bottom-.07,1.62,.20,11.04,11.65)
    for z in (1.0,3.45):
        block('Belfry | weathered string course',x,z,2.55,.13,11.19,11.56)
    # Surviving bell on a dark timber crossbeam inside the opening.
    block('Belfry | timber headstock',x,spring+.25,1.15,.13,11.91,12.12,
          bpy.data.materials['outer | shattered roof timber'] if 'outer | shattered roof timber' in bpy.data.materials else bronze)
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=.37,radius2=.19,depth=.54,location=(x,12.03,spring-.08))
    bell=bpy.context.object
    for coll in tuple(bell.users_collection):
        coll.objects.unlink(bell)
    place(bell,'Belfry | surviving bronze bell',bronze)

# The broken rose sits inside a layered pointed frame carried by stepped masonry.
for side in (-1,1):
    for row in range(8):
        z=2.92+row*.29
        for offset,width,depth in ((1.96,.36,13.28),(2.27,.27,13.43)):
            block('Rose bay | pier ashlar',side*(offset+(.055 if row%2 else 0)),z,width,.27,depth-.17,14.0,wall)
    for z,width in ((2.96,.76),(4.83,.68),(5.12,.64)):
        block('Rose bay | pier moulding',side*2.08,z,width,.16,12.98,13.92)
arch('Rose bay | broken inner archivolt',0,5.1,1.88,2.15,.23,12.92,13.48,10,((1,6),(1,7),(1,8),(1,9)))
arch('Rose bay | outer weathered archivolt',0,5.1,2.13,2.43,.25,13.05,13.71,10,((1,5),(1,6),(1,7),(1,8),(1,9),(-1,9)))
for side in (-1,1):
    for row in range(5):
        block('Rose bay | fallen facing stone',side*(1.65+row*.15),3.03-row*.025,
              .25+rng.random()*.25,.14,12.8-rng.random()*.4,13.15,wall)

# Preserve the crystals' footprints and break the uniform caps into irregular facets.
for obj in scene.objects:
    if not any(tag in obj.name for tag in ('wild crystal outcrop','crystal blight outcrop','encircling vessel splinter')):
        continue
    vertices=obj.data.vertices
    if len(vertices)!=19:
        continue
    base=sum((v.co for v in list(vertices)[:6]),Vector())/6
    height=vertices[18].co.z-base.z
    for ring in (1,2):
        for index in range(6):
            vertex=vertices[ring*6+index]
            vertex.co.z+=height*rng.uniform(-.045,.045)
            factor=rng.uniform(.9,1.08)
            vertex.co.x=base.x+(vertex.co.x-base.x)*factor
            vertex.co.y=base.y+(vertex.co.y-base.y)*factor
    obj.data.update()

for name, tint in (('outer | dormant blue crystal',(.075,.16,.24,1)),
                   ('outer | suppressed purple crystal',(.13,.075,.24,1))):
    material=bpy.data.materials[name]
    shader=material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=tint
    shader.inputs['Emission Strength'].default_value=.022
    shader.inputs['Roughness'].default_value=.26
    shader.inputs['Coat Weight'].default_value=.3
    material.diffuse_color=tint

bpy.data.objects['cold dusk skylight'].data.energy=2100
bpy.data.objects['cool nave fill'].data.energy=530
bpy.data.objects['warm sanctuary rim'].data.energy=480
scene['Hollowmark build']='V6 | Broken Rose'
scene.render.filepath='//Hollowmark Last Benediction V6 Preview.png'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(output/'Hollowmark Last Benediction V6.blend'))
bpy.ops.render.render(write_still=True)

