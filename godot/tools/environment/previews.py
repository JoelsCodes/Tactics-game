"""Render controlled Blender asset thumbnails and embed them in the catalogue files."""
import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from assemble import bounds, camera_light, make_collection
from envlib import asset_index


def preview(root, asset):
    source=root/asset["file"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(source),link=False) as (fr,to):
        material=asset["category"]=="Materials"
        if material:
            to.materials=[asset["name"]]
        else:
            to.collections=[asset["name"]]
    scene=bpy.context.scene
    if material:
        item=to.materials[0]
        bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,radius=.8)
        obj=bpy.context.object
        obj.data.materials.append(item)
        for face in obj.data.polygons:
            face.use_smooth=True
        objects=[obj]
    else:
        item=to.collections[0]
        scene.collection.children.link(item)
        objects=list(item.all_objects)
    if asset["status"] not in {tag.name for tag in item.asset_data.tags}:
        item.asset_data.tags.new(asset["status"])
    low,high=map(Vector,bounds(objects))
    center=(low+high)*.5
    size=(high-low).length
    camera_light(scene,{"location":center+size*Vector((.84,-1.6,.93)),
                        "target":center,"ortho_scale":size*1.19},make_collection("RENDER_HELPERS"))
    scene.view_settings.view_transform="AgX"
    scene.view_settings.look="AgX - Medium High Contrast"
    scene.render.engine="CYCLES"
    scene.cycles.samples=32
    scene.cycles.use_denoising=False
    scene.render.resolution_x=scene.render.resolution_y=400
    scene.render.resolution_percentage=100
    path=root/asset["category"]/(asset["id"]+"-preview.png")
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    with bpy.context.temp_override(id=item):
        bpy.ops.ed.lib_id_load_custom_preview(filepath=str(path))
    if not item.preview or not item.preview.image_size[0]:
        raise ValueError(f'Could not install thumbnail for {asset["id"]}')
    dimensions=[round(value,4) for value in high-low]
    staged=source.with_name(source.stem+"-staged.blend")
    scene.render.filepath="//asset-preview.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(staged),compress=True)
    staged.replace(source)
    print("NATIVE_PREVIEW",asset["id"],list(item.preview.image_size),dimensions)


# Fixed views make successive versions comparable without resizing or reframing in post.
DETAIL_VIEWS = {
    "wall": ((1.7,-5.4,2.5),(-.22,-.28,1.1),3.6),
    "arch": ((2.8,-7.1,5.0),(.13,0,1.95),5.9),
    "stairs": ((4.14,-4.84,3.77),(.29,1.48,.92),5.45),
    "cliff": ((3.45,-7.15,4.53),(.10,-.30,1.48),7.9),
    "terrace": ((3.55,-5.45,4.7),(.1,-.24,-.15),7.85),
}


def render_detail(scene, path):
    scene.view_settings.view_transform="AgX"
    scene.render.engine="CYCLES"
    scene.cycles.samples=36
    scene.cycles.use_denoising=False
    scene.render.resolution_x=768
    scene.render.resolution_y=560
    scene.render.resolution_percentage=100
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)


def texture_sample(material):
    bpy.ops.mesh.primitive_plane_add(size=1.98)
    panel=bpy.context.object
    panel.data.materials.append(material)
    for loop in panel.data.uv_layers.active.data:
        loop.uv *= 1.98 / material["repeat_m"]
    edge=panel.modifiers.new("Thickness","SOLIDIFY")
    edge.thickness=.061


def details(root, entries, output):
    output.mkdir(parents=True,exist_ok=True)
    for asset in entries:
        key=asset["id"]
        if key not in DETAIL_VIEWS and key!="limestone":
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        view_helpers=make_collection("RENDER_HELPERS")
        with bpy.data.libraries.load(str(root/asset["file"]),link=False) as (src,dst):
            if key=="limestone":
                dst.materials=[asset["name"]]
            else:
                dst.collections=[asset["name"]]
        scene=bpy.context.scene
        if key=="limestone":
            texture_sample(dst.materials[0])
            camera_light(scene,{"location":(.30,-2.34,2.75),"target":(0,0,0),"ortho_scale":2.75},view_helpers)
            for ob in list(view_helpers.objects):
                if ob.type=="LIGHT":
                    bpy.data.objects.remove(ob,do_unlink=True)
            key_light=bpy.data.lights.new("Material test key","AREA")
            key_object=bpy.data.objects.new("Material test key",key_light)
            view_helpers.objects.link(key_object)
            for label,location,power,size,ambient in (
                ("neutral",(-.48,-.72,2.43),160,1.65,.55),
                ("grazing",(-1.95,.51,.25),250,.46,.16),
            ):
                key_object.location=location
                key_object.rotation_euler=(-key_object.location).to_track_quat("-Z","Y").to_euler()
                key_light.energy=power
                key_light.size=size
                scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.42,.42,.42,1)
                scene.world.node_tree.nodes["Background"].inputs[1].default_value=ambient
                render_detail(scene,output/f"limestone-{label}.png")
        else:
            scene.collection.children.link(dst.collections[0])
            location,target,scale=DETAIL_VIEWS[key]
            camera_light(scene,{"location":location,"target":target,"ortho_scale":scale},view_helpers)
            render_detail(scene,output/f"{key}.png")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("library",type=Path)
    parser.add_argument("--details",type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    root=args.library.resolve()
    entries=[a for a in asset_index(root).values() if a.get("file")]
    if args.details:
        details(root,entries,args.details.resolve())
    else:
        for asset in entries:
            preview(root,asset)
