"""Build previews and GLB from explicit placements while keeping gameplay inputs immutable."""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from envlib import STATUS, asset_index, choose, digest, read


def make_collection(label):
    col = bpy.data.collections.get(label)
    if col is None:
        col = bpy.data.collections.new(label)
        bpy.context.scene.collection.children.link(col)
    return col


def append_collection(root, asset, vec, degrees, destination, cache):
    key = asset["id"]
    if key not in cache:
        with bpy.data.libraries.load(str(root / asset["file"]), link=False) as (src, dst):
            if asset["name"] not in src.collections:
                raise ValueError(f"Asset collection missing: {asset['name']}")
            dst.collections = [asset["name"]]
        cache[key] = dst.collections[0]
    original = cache[key]
    # Explicit mesh objects preserve instances' geometry, modifiers, and glTF export.
    import mathutils
    matrix = mathutils.Matrix.Translation(vec) @ mathutils.Matrix.Rotation(math.radians(degrees),4,"Z")
    meshes=[]
    for item in original.all_objects:
        if item.type!="MESH":
            raise ValueError(f"{key} contains an unsupported member {item.name}")
        copy=item.copy()
        destination.objects.link(copy)
        copy.parent=None
        copy["hollowmark_asset_part"]=key+":"+item.name
        copy.matrix_world=matrix @ item.matrix_world
        meshes.append(copy)
    return meshes


def camera_light(scene, spec, helpers):
    target=Vector(spec["target"])
    camera=bpy.data.objects.new("Tactical preview camera",bpy.data.cameras.new("Tactical preview camera"))
    helpers.objects.link(camera)
    camera.location=spec["location"]
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO"
    camera.data.ortho_scale=spec["ortho_scale"]
    scene.camera=camera
    for name,location,color,energy,size in (
            ("Late sun bounce",(1,-5,10),(1,.79,.59),2050,4),
            ("Cool valley fill",(-8,-1,5),(.46,.65,1),550,7),
            ("Warm rim",(3,8,10),(1,.82,.56),2800,5)):
        light=bpy.data.lights.new(name,"AREA")
        light.energy=energy
        light.color=color
        light.shape="DISK"
        light.size=size
        obj=bpy.data.objects.new(name,light)
        helpers.objects.link(obj)
        obj.location=location
        obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.world=bpy.data.worlds.new("Diffuse sky")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.18,.24,.31,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.26


def audited_shader(material):
    if not material or not material.use_nodes:
        raise ValueError("Mesh with missing/default material")
    nodes=material.node_tree.nodes
    output=next((n for n in nodes if n.type=="OUTPUT_MATERIAL" and n.is_active_output),None)
    if not output or not output.inputs["Surface"].is_linked:
        raise ValueError(f"{material.name}: no active shader")
    shader=output.inputs["Surface"].links[0].from_node
    if shader.type!="BSDF_PRINCIPLED":
        raise ValueError(f"{material.name}: non-glTF shader")
    for name in ("Base Color","Roughness","Normal","Metallic","Alpha","Emission Color"):
        inp=shader.inputs[name]
        if not inp.is_linked:
            continue
        n=inp.links[0].from_node
        if name=="Normal":
            if n.type!="NORMAL_MAP" or n.space!="TANGENT" or not n.inputs["Color"].is_linked:
                raise ValueError(f"{material.name}: invalid tangent-space normal")
            n=n.inputs["Color"].links[0].from_node
        if n.type!="TEX_IMAGE" or not n.image or not n.image.packed_file:
            raise ValueError(f"{material.name}: {name} requires a packed image texture")
        if n.inputs["Vector"].is_linked:
            source = n.inputs["Vector"].links[0]
            if source.from_node.type != "UVMAP" and not (source.from_node.type == "TEX_COORD" and source.from_socket.name == "UV"):
                raise ValueError(f"{material.name}: {name} requires explicit mesh UVs")
        want="sRGB" if name in ("Base Color","Alpha","Emission Color") else "Non-Color"
        if n.image.colorspace_settings.name!=want and name!="Alpha":
            raise ValueError(f"{material.name}: {name} must use {want}")


def bounds(objects):
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    points=[o.matrix_world @ Vector(p) for ob in objects
            for o in (ob.evaluated_get(deps),) for p in o.bound_box]
    return [[round(fn(p[j] for p in points),5) for j in range(3)] for fn in (min,max)]


def build(root, brief_path, output):
    brief=read(brief_path)
    anchor=brief_path.parent
    if brief["mode"] not in ("asset_review","battle_map"):
        raise ValueError("Unknown brief mode")
    refs=[(anchor/Path(p)).resolve() for p in brief["references"]]
    if not refs or not all(p.is_file() for p in refs) or not brief["reference_read"]:
        raise ValueError("An inspected art reference and a recorded reading are required")
    nav=anchor/brief["navigation"] if brief.get("navigation") else None
    if brief["mode"]=="battle_map" and not nav:
        raise ValueError("Supply the authoritative gameplay file")
    if nav:
        source_nav=read(nav)
        if not isinstance(source_nav,dict):
            raise ValueError("Gameplay source must be a JSON object")
    approved=asset_index(root)
    base=anchor/brief["existing_blend"] if brief.get("existing_blend") else None
    if base:
        bpy.ops.wm.open_mainfile(filepath=str(base.resolve()))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.unit_settings.system="METRIC"
    scene.unit_settings.scale_length=1
    play=make_collection("VISUAL_PLAYABLE")
    exterior=make_collection("VISUAL_NONPLAY")
    helpers=make_collection("RENDER_HELPERS")
    guides=make_collection("GAMEPLAY_REFERENCE")
    guides.hide_render=True
    guides.hide_viewport=True
    old_camera=scene.camera
    meshes=[]
    if base:
        names=brief.get("export_collections",[])
        if not names:
            raise ValueError("Explicit export_collections required when opening an existing scene")
        meshes=[ob for name in names for ob in bpy.data.collections[name].all_objects if ob.type=="MESH"]
    decisions=[]
    cache={}
    for p in brief["placements"]:
        key=p.get("asset")
        if not key:
            query=p["query"]
            options=choose(root,query,p.get("tags",[]),p.get("fits_m"))
            matches=[a for a in options if a["action"]=="REUSE" and a.get("file") and a["category"]!="Materials"]
            if not matches:
                raise ValueError(f"{query}: {options[0]['action']} required before assembly")
            key=matches[0]["id"]
        asset=approved[key]
        if asset["status"]=="Prototype" or (brief["mode"]=="battle_map" and asset["status"]!="Production Ready"):
            raise ValueError(f'Asset not approved for this mode: {asset["id"]}')
        if p["layer"] not in ("playable","exterior"):
            raise ValueError(f'Invalid visual layer for {asset["id"]}')
        target=play if p["layer"]=="playable" else exterior
        meshes.extend(append_collection(root,asset,p["location"],p.get("yaw",0),target,cache))
        decisions.append({"asset":asset["id"],"decision":STATUS[asset["status"]],"layer":p["layer"]})
    meshes=list(dict.fromkeys(meshes))
    if not meshes:
        raise ValueError("No geometry to export")
    for ob in meshes:
        if not ob.data.uv_layers or not ob.material_slots:
            raise ValueError(f"Missing UVs or material slots: {ob.name}")
        for slot in ob.material_slots:
            audited_shader(slot.material)
    if old_camera is None:
        if base:
            raise ValueError("Existing scene has no assigned tactical camera")
        camera_light(scene,brief["camera"],helpers)
    elif old_camera != scene.camera:
        raise ValueError("Existing tactical camera unexpectedly changed")
    box=bounds(meshes)
    output.mkdir(parents=True,exist_ok=False)
    shutil.copyfile(brief_path,output/"brief.json")
    shutil.copyfile(root/"ASSET_LICENSES.json",output/"ASSET_LICENSES.json")
    if nav:
        shutil.copyfile(nav,output/"navigation.json")
        if digest(nav)!=digest(output/"navigation.json"):
            raise ValueError("Gameplay source was changed")
    if not base:
        scene.view_settings.view_transform="AgX"
        scene.view_settings.look="AgX - Medium High Contrast"
    scene.render.engine="CYCLES"
    scene.cycles.samples=brief.get("samples",20)
    scene.cycles.use_denoising=brief.get("denoise",False)
    scene.render.resolution_x,scene.render.resolution_y=brief.get("resolution",[960,540])
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath="//preview.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(output/"map.blend"),compress=True,relative_remap=False)
    bpy.ops.object.select_all(action="DESELECT")
    baked={}
    saved=[]
    for ob in meshes:
        ob.select_set(True)
        part=ob.get("hollowmark_asset_part") if not base else None
        if part is None:
            saved.append((ob,ob.modifiers.new("Triangulate for glTF tangents","TRIANGULATE")))
            continue
        # All placements of this part share an evaluated mesh. The Blender master remains editable.
        if part not in baked:
            ob.modifiers.new("Triangulate for glTF tangents","TRIANGULATE")
            bpy.context.view_layer.update()
            deps=bpy.context.evaluated_depsgraph_get()
            baked[part]=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
        ob.modifiers.clear()
        ob.data=baked[part]
    bpy.ops.export_scene.gltf(filepath=str(output/"map.glb"),export_format="GLB",use_selection=True,
                              export_apply=bool(saved),export_tangents=True,export_cameras=False,export_lights=False)
    for ob,modifier in saved:
        ob.modifiers.remove(modifier)
    scene.render.filepath=str(output/"preview.png")
    bpy.ops.render.render(write_still=True)
    cam=scene.camera
    camera={"location":list(cam.location),"quaternion":list(cam.rotation_euler.to_quaternion()),
            "projection":cam.data.type,"ortho_scale":cam.data.ortho_scale}
    names=["map.blend","map.glb","preview.png","brief.json","ASSET_LICENSES.json"]+(["navigation.json"] if nav else [])
    data={"mode":brief["mode"],"references":[{"name":p.name,"sha256":digest(p)} for p in refs],
          "files":{n:digest(output/n) for n in names},"bounds_xyz_m":box,"camera":camera,
          "decisions":decisions,"mesh_objects":len(meshes),"godot_probes":brief.get("godot_probes",[])}
    (output/"build.json").write_text(json.dumps(data,indent=2)+"\n")
    print("HOLLOWMARK_BUILD",json.dumps({"file":str(output),"meshes":len(meshes),"bounds":box}))


if __name__=="__main__":
    cli=argparse.ArgumentParser()
    for arg in ("library","brief","output"):
        cli.add_argument(arg,type=Path)
    a=cli.parse_args(sys.argv[sys.argv.index("--")+1:])
    build(*(p.resolve() for p in (a.library,a.brief,a.output)))
