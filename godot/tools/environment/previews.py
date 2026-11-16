"""Render controlled Blender asset thumbnails and embed them in the catalogue files."""
import argparse
import math
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


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("library",type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    root=args.library.resolve()
    for asset in asset_index(root).values():
        if asset.get("file"):
            preview(root,asset)
