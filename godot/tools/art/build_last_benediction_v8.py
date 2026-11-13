"""Run in Blender 5.3 with V7 loaded and an outputs directory in the workspace."""

import bpy, math
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

scene=bpy.context.scene
out=Path('outputs').resolve()
outer=bpy.data.collections['NONPLAY | World beyond battlefield']
terrain_material=bpy.data.materials['outer | deep recessed masonry']
original_ground=bpy.data.objects['NONPLAY | high war-scarred ground']
if original_ground.data.materials:
    terrain_material=original_ground.data.materials[0]
# Grade the surrounding earth up against the nave without covering a single tile.
coords=sorted(set([i*.5 for i in range(-84,85)]+[-7.02,7.02]))
vertices=[]
for y in coords:
    for x in coords:
        distance=max(abs(x),abs(y))-7.02
        edge=max(0,min(1,distance/3.0))
        value=noise_vector(Vector((x*.31,y*.31,.62)))[0]
        front=math.exp(-((x/2.9)**2))*max(0,min(1,(-y-7)/2.5))
        z=-.32-.63*edge+value*(.09+.2*edge)-.12*front
        if y>7:
            z=min(z,-.20)
        vertices.append((x,y,z))
faces=[]
n=len(coords)
for j in range(n-1):
    for i in range(n-1):
        x=(coords[i]+coords[i+1])/2
        y=(coords[j]+coords[j+1])/2
        if max(abs(x),abs(y))<7.02:
            continue
        k=j*n+i
        faces.append((k,k+1,k+n+1,k+n))
mesh=bpy.data.meshes.new('Graded cathedral grounds')
mesh.from_pydata(vertices,[],faces)
mesh.update()
uv=mesh.uv_layers.new(name='UVMap')
for poly in mesh.polygons:
    poly.use_smooth=True
    for index in poly.loop_indices:
        v=mesh.vertices[mesh.loops[index].vertex_index].co
        uv.data[index].uv=(v.x/2.3,v.y/2.3)
ground=bpy.data.objects.new('NONPLAY | Graded cathedral grounds',mesh)
outer.objects.link(ground)
ground.data.materials.append(terrain_material)
ground['collision_role']='visual_only'
for obj in list(outer.all_objects):
    if any(k in obj.name for k in ('high war-scarred ground','bottom strata','natural terraced strata')):
        bpy.data.objects.remove(obj,do_unlink=True)

cam=scene.camera
cam.data.ortho_scale=34.2
cam.rotation_euler=(Vector((0,3,1.3))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1920
scene.render.resolution_y=1080
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.46
world=scene.world.node_tree.nodes.get('Background')
world.inputs['Color'].default_value=(.16,.22,.34,1)
world.inputs['Strength'].default_value=.42
for name, power, color in (
 ('cold dusk skylight',2250,(.61,.74,1)),
 ('warm sanctuary rim',1020,(1,.59,.32)),
 ('cool nave fill',600,(.69,.79,1)),
 ('altar purple bounce',380,(.59,.44,1)),
 ('muted warm war-remnant',1080,(1,.56,.29))):
    light=bpy.data.objects[name].data
    light.energy=power
    light.color=color
for obj in scene.objects:
    if obj.name.startswith('V5 | torch reflected firelight'):
        obj.data.energy=145
        obj.data.color=(1,.43,.16)

# Keep the larger shadowed floor masses readable and let the vessel carry the violet.
for name in ('violet luminous crystal','icy blue luminous crystal'):
    shader=bpy.data.materials[name].node_tree.nodes.get('Principled BSDF')
    color=shader.inputs['Base Color'].default_value
    shader.inputs['Base Color'].default_value=tuple(c*.58 for c in color[:3])+(1,)
    shader.inputs['Emission Strength'].default_value=.043
    shader.inputs['Roughness'].default_value=.30
    shader.inputs['Coat Weight'].default_value=.25

# Preserve texture detail while grading the ground at the scale of the whole site.
mat=terrain_material.copy()
mat.name='Cathedral grounds | damp stone and ash'
ground.data.materials[0]=mat
nodes=mat.node_tree.nodes
links=mat.node_tree.links
shader=nodes.get('Principled BSDF')
socket=shader.inputs['Base Color']
source=socket.links[0].from_socket if socket.is_linked else None
tex=nodes.new('ShaderNodeTexCoord')
noise=nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=.24
noise.inputs['Detail'].default_value=3
links.new(tex.outputs['Object'],noise.inputs['Vector'])
ramp=nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].position=.25
ramp.color_ramp.elements[0].color=(.30,.32,.24,1)
ramp.color_ramp.elements[1].position=.72
ramp.color_ramp.elements[1].color=(.85,.73,.57,1)
links.new(noise.outputs['Fac'],ramp.inputs[0])
mix=nodes.new('ShaderNodeMixRGB')
mix.blend_type='MULTIPLY'
mix.inputs[0].default_value=.68
if source:
    links.new(source,mix.inputs[1])
else:
    mix.inputs[1].default_value=socket.default_value
links.new(ramp.outputs['Color'],mix.inputs[2])
links.new(mix.outputs['Color'],socket)
cam.data.ortho_scale=36.5
cam.rotation_euler=(Vector((0,3.4,1.7))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.data.objects['warm sanctuary rim'].data.energy=850

scene['Hollowmark build']='V8 | Cathedral Grounds'
scene.render.filepath='//Hollowmark Last Benediction V8 Preview.png'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Hollowmark Last Benediction V8.blend'))
bpy.ops.render.render(write_still=True)


