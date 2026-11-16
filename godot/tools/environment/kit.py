"""Author the first Hollowmark kit as native Blender collection/material assets."""
import argparse
import json
import math
import random
import sys
import uuid
from collections import defaultdict
from pathlib import Path

import bpy
from mathutils import Vector

CATEGORIES = ("Architecture", "Terrain", "Materials", "Nature", "Water", "Map_Templates", "Scripts")
ASSETS = {
    "wall": ("Architecture", "Ashlar Wall", "4 m bays with bonded drip courses, stepped plinth and coping. Origin at the base center.", ["masonry", "ruin", "retaining"]),
    "arch": ("Architecture", "Vaulted Gateway", "2.68 m clear opening. Full-depth voussoirs, jambs and radial mouldings. Origin at threshold center.", ["ruin", "gateway", "masonry"]),
    "stairs": ("Architecture", "Limestone Stair", "3.6 m-wide route. Nine 0.18 m risers and 0.34 m treads. Origin at first riser.", ["elevation", "masonry", "terrace"]),
    "cliff": ("Terrain", "Faulted Limestone Escarpment", "Irregular sedimentary ledge, exposed faults and apron. Local Z=0 at the foot.", ["cliff", "terrain", "ruin"]),
    "limestone": ("Materials", "Honed Limestone", "Image-backed pale cut-stone finish. 1.6 m UV repeat for architectural modules.", ["stone", "pbr", "masonry"]),
    "terrace": ("Terrain", "Irregular Stone Court", "Continuous paved formation with staggered sett courses. Origin at center of walking plane.", ["terrain", "paving", "terrace"]),
}
rng = random.Random(2132)
groups = defaultdict(lambda: ([], [], []))


def material(name, directory, names, repeat, tint=(1, 1, 1), strength=1):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat["repeat_m"] = repeat
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    for slot, suffix in names.items():
        img = bpy.data.images.load(str(directory / suffix), check_existing=True)
        img.colorspace_settings.name = "sRGB" if slot == "Base Color" else "Non-Color"
        img.pack()
        node = nodes.new("ShaderNodeTexImage")
        node.image = img
        node.label = slot
        if slot == "Normal":
            normal = nodes.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = strength
            links.new(node.outputs["Color"], normal.inputs["Color"])
            links.new(normal.outputs["Normal"], shader.inputs["Normal"])
        else:
            links.new(node.outputs["Color"], shader.inputs[slot])
    mat.diffuse_color = (*tint, 1)
    return mat


def solid(part, mat, profile, lo, hi, vertical=False, tone=0, side=False):
    """Extrude a cut-stone profile in XY or XZ, with per-face tiled UVs."""
    v, f, data = groups[(part, mat)]
    start, n = len(v), len(profile)
    for depth in (lo, hi):
        v.extend((depth, a, b) if side else (a, depth, b) if vertical else (a, b, depth)
                 for a, b in profile)
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    for face in faces:
        f.append(tuple(start+i for i in (reversed(face) if vertical else face)))
        data.append(tone)


def block(part, mat, x0, x1, y0, y1, z0, z1, chip=.022, tone=0):
    c = min(chip, (x1-x0)*.22, (y1-y0)*.22)
    a,b,d = (c*rng.uniform(.35,1.3) for _ in range(3))
    outline = [(x0+a,y0),(x1-b,y0),(x1,y0+b),(x1,y1-a),
               (x1-a,y1),(x0+d,y1),(x0,y1-d),(x0,y0+a)]
    solid(part,mat,outline,z0,z1,tone=tone)


def masonry(x0, x1, y0, y1, z0, course_count, height=.29):
    for row in range(course_count):
        x = x0
        z = z0+row*height
        while x < x1-.001:
            nominal = (.46 if row%2 else .83) if x == x0 else rng.uniform(.60,1.02)
            end = min(x+nominal,x1)
            if x1-end < .27:
                end = x1
            lip = rng.uniform(-.012,.016)
            block("Bonded courses",stone,x+.007,end-.007,y0-lip,y1+lip,z+.007,z+height-.007,
                  rng.uniform(.014,.041),rng.random())
            x=end


def wall():
    block("Recessed wall core",stone,-1.99,1.99,-.23,.23,.09,1.95)
    masonry(-2,2,-.275,.275,.16,6)
    for z,w,h in ((0,.74,.15),(.15,.64,.10),(1.88,.64,.09),(1.97,.76,.13)):
        for x in (-2,-1,0,1):
            block("Drip course and plinth",stone,x+.008,x+.992,-w/2,w/2,z,z+h,.025,rng.random())


def arch():
    spring,radius,ring = 1.93,1.34,1.76
    for a,b in ((-2.27,-1.355),(1.355,2.27)):
        masonry(a,b,-.40,.40,.08,7,.263)
        for z,w,h in ((0,.99,.14),(1.73,.98,.10),(1.83,1.05,.105)):
            block("Foot and impost",stone,a-.085,b+.085,-w/2,w/2,z,z+h,.023,rng.random())
    for i in range(19):
        a,b = i*math.pi/19+.008,(i+1)*math.pi/19-.008
        def arc(inner, outer, start, end):
            angles=[start+(end-start)*j/4 for j in range(5)]
            return [(r*math.cos(t),spring+r*math.sin(t)) for r, seq in ((outer,angles),(inner,angles[::-1])) for t in seq]
        solid("Structural radial voussoirs",stone,arc(radius,ring,a,b),-.414,.414,True,rng.random())
        key = .087 if i==9 else 0
        for inner,outer,depth in ((1.34,1.44,.462),(1.575,1.635,.458),(1.649,1.775+key,.451)):
            solid("Cut concentric archivolt",stone,arc(inner,outer,a,b),-depth,depth,True,rng.random())
        if i not in (8,9,10):
            p,q = i*math.pi/19+.005,(i+1)*math.pi/19-.005
            pts=[(ring*math.cos(t),spring+ring*math.sin(t)) for t in (p,q)]
            x0,z0=pts[0];x1,z1=pts[1]
            solid("Backed spandrel",stone,[pts[0],(x0,3.68),(x1,3.68),pts[1]],-.36,.36,True,rng.random())
    for x in (-1.96,1.96):
        masonry(x-.31,x+.31,-.38,.38,1.94,6,.286)
    for x in (-2.25,-1.50,-.75,0,.75,1.50):
        block("Crown cornice",stone,x+.006,x+.744,-.53,.53,3.66,3.82,.023,rng.random())
        block("Crown cap",stone,x+.006,x+.744,-.58,.58,3.82,3.92,.023,rng.random())
    for x in (-1.997,1.997):
        for i in range(5):
            block("Engaged buttress",stone,x-.18,x+.18,-.59,-.34,.14+i*.315,
                  .446+i*.315,.026,rng.random())


def stairs():
    for i in range(9):
        z=(i+1)*.18
        y=i*.34
        for a,b in zip((-1.8,-.82,.28,1.35) if i%2 else (-1.8,-1.05,.12,1.07),
                       (-.82,.28,1.35,1.8) if i%2 else (-1.05,.12,1.07,1.8)):
            block("Jointed stone treads",stone,a+.005,b-.005,y-.024,y+.34,z-.20,z,.013,rng.random())
        block("Stair undercroft",stone,-1.78,1.78,y+.014,y+.344,-.07,z-.16,.014,.25)
    for x in (-2.03,2.03):
        profile=[(0,-.02),(3.06,-.02),(3.06,1.87),(0,.28)]
        solid("Sloping closed-string support",stone,profile,x-.21,x+.21,side=True)
        for i in range(9):
            y=i*.34
            solid("Running stair coping",stone,[(y,.27+i*.18),(y+.334,.447+i*.18),
                  (y+.334,.552+i*.18),(y,.375+i*.18)],x-.268,x+.268,side=True,tone=rng.random())


def rock_lobe(cx, cy, base, width, depth, height):
    verts, faces, tones=groups[("Fractured rock strata",rock)]
    start=len(verts)
    n=17
    phases=[2*math.pi*i/n for i in range(n)]
    ribs=[rng.uniform(.78,1.21) for _ in phases]
    levels=(0,.12,.27,.33,.46,.63,.69,.82,.96,1)
    scales=(.77,.94,1.03,.95,1.07,.94,.96,.82,.70,.44)
    for row,(elevation,scale) in enumerate(zip(levels,scales)):
        for j,t in enumerate(phases):
            tangential=t+.05*math.sin(row*.64+j)
            f=ribs[j]*scale*rng.uniform(.92,1.10)
            h=height*(elevation+.043*math.sin(t*2+1)+rng.uniform(-.015,.015))
            verts.append((cx+width*f*math.cos(tangential)+.17*elevation,cy+depth*f*math.sin(tangential),base+h))
    faces.append(tuple(start+i for i in reversed(range(n))))
    tones.append(.2)
    for row in range(len(levels)-1):
        a=start+row*n;b=a+n
        for j in range(n):
            k=(j+1)%n
            faces.extend(((a+j,a+k,b+j),(a+k,b+k,b+j)))
            tones.extend((.18,.18))
    faces.append(tuple(start+(len(levels)-1)*n+i for i in range(n)))
    tones.append(.2)


def cliff():
    rock_lobe(.25,.17,0,2.07,1.0,3.2)
    rock_lobe(-1.55,-.03,-.09,1.35,1.18,2.53)
    rock_lobe(1.70,.11,-.05,1.28,1.03,2.21)
    rock_lobe(.95,-.66,-.05,1.04,.84,1.32)
    rock_lobe(-.95,-.72,-.06,1.0,.60,1.12)
    for x,y,w,d,h in ((-2.2,-.88,.57,.47,.63),(1.63,-1.29,.43,.44,.41),
                      (-.21,-1.26,.61,.51,.44),(-2.09,-1.57,.36,.46,.28)):
        rock_lobe(x,y,-.04,w,d,h)


def terrace():
    block("Set paving bed",stone,-3.16,3.16,-2.16,2.16,-.25,-.067,.10)
    plate=((-3.22,-1.80),(-2.91,-2.20),(2.93,-2.20),(3.24,-1.80),
           (3.24,1.82),(2.99,2.20),(-2.95,2.20),(-3.22,1.90))
    for face_y in (-2.125, 2.125):
        masonry(-3.03,3.03,face_y-.11,face_y+.11,-.64,2,.279)
    for face_x in (-3.11,3.11):
        for y in (-1.62,-.81,0,.81,1.62):
            block("Bonded court foundations",stone,face_x-.12,face_x+.12,y-.396,y+.397,-.64,-.089,.033,rng.random())
    solid("Inset mineral bedding",paving,plate,-.085,-.017)
    for row in range(8):
        y=-2.02+row*.50
        inset=.16 if row in (0,7) else 0
        x=-3.11+inset
        end=3.12-inset
        while end-x>.005:
            length=(.48 if row%2 else .83) if x==-3.11+inset else rng.uniform(.70,1.19)
            limit=min(x+length,end)
            if end-limit<.25:
                limit=end
            block("Staggered limestone flagstones",stone,x+.009,limit-.009,y,y+.482,-.035,
                  rng.uniform(-.008,.005),rng.uniform(.024,.055),rng.random())
            x=limit
    for y in (-2.145,2.145):
        for i in range(7):
            x=-3.08+i*.89
            block("Worked margin setts",stone,x,x+.871,y-.078,y+.078,-.11,.018,.027,rng.random())


def bake_geometry(collection):
    for (part,mat),(verts,faces,tones) in groups.items():
        mesh=bpy.data.meshes.new(part)
        mesh.from_pydata(verts,[],faces)
        mesh.update()
        obj=bpy.data.objects.new(part,mesh)
        collection.objects.link(obj)
        mesh.materials.append(mat)
        uv=mesh.uv_layers.new(name="Metres")
        repeat=mat["repeat_m"]
        for p,tone in zip(mesh.polygons,tones):
            axis=max(range(3),key=lambda i:abs(p.normal[i]))
            a,b=((1,2),(0,2),(0,1))[axis]
            flip = -1 if (p.normal[axis]<0) != (axis==1) else 1
            offset=round(tone*167)/17 if mat==stone else 0
            for idx in p.loop_indices:
                position=verts[mesh.loops[idx].vertex_index]
                uv.data[idx].uv=(position[a]*flip/repeat+offset,position[b]/repeat+offset*.43)
        if mat==stone and part!="Stair undercroft":
            bevel=obj.modifiers.new("Mason-dressed edges","BEVEL")
            bevel.width=.018 if part=="Bonded courses" else .011
            bevel.segments=2
            bevel.affect="EDGES"
            bevel.limit_method="ANGLE"
            smooth=obj.modifiers.new("Face-weighted corner normals","WEIGHTED_NORMAL")
            smooth.keep_sharp=True
    groups.clear()


def catalog(category):
    return str(uuid.uuid5(uuid.NAMESPACE_URL,"hollowmark-environment/"+category))


def mark(item, key):
    category,name,description,tags=ASSETS[key]
    item.asset_mark()
    meta=item.asset_data
    meta.author="Hollowmark Tactics"
    meta.description=description
    meta.catalog_id=catalog(category)
    for tag in (*tags, "Needs Improvement"):
        meta.tags.new(tag)


def stage_kit(root):
    global stone,rock,paving
    textures=root/"Materials"/"Textures"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    stone=material("Honed Limestone",textures/"Limestone",{"Base Color":"color.jpg","Roughness":"roughness.jpg","Normal":"normal.jpg"},1.6,(.63,.57,.44),.66)
    rock=material("Weathered Escarpment",textures/"Rock051",{"Base Color":"Rock051_1K-JPG_Color.jpg","Roughness":"Rock051_1K-JPG_Roughness.jpg","Normal":"Rock051_1K-JPG_NormalGL.jpg"},2.6,(.36,.34,.30),.86)
    paving=material("Weathered Stone Floor",textures/"stone_floor",{"Base Color":"stone_floor_diff_1k.jpg","Roughness":"stone_floor_rough_1k.jpg","Normal":"stone_floor_nor_gl_1k.jpg"},1.8,(.42,.35,.23))
    mark(stone,"limestone")
    functions={"wall":wall,"arch":arch,"stairs":stairs,"cliff":cliff,"terrace":terrace}
    (root/"blender_assets.cats.txt").write_text("VERSION 1\n"+"".join(f"{catalog(cat)}:{cat}:{cat}\n" for cat in CATEGORIES))
    for key,function in functions.items():
        category,name,*_=ASSETS[key]
        collection=bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        function()
        bake_geometry(collection)
        mark(collection,key)
        bpy.data.libraries.write(str(root/category/(key+".blend")),{collection},fake_user=True,compress=True)
        bpy.context.scene.collection.children.unlink(collection)
    bpy.data.libraries.write(str(root/"Materials"/"limestone.blend"),{stone},fake_user=True,compress=True)


def register(root):
    libraries = bpy.context.preferences.filepaths.asset_libraries
    name="Hollowmark Environment Library"
    existing=next((lib for lib in libraries if lib.name==name),None)
    if existing and Path(bpy.path.abspath(existing.path)).resolve()!=root.resolve():
        raise ValueError(f"{name} is already registered at {existing.path}")
    if existing is None:
        bpy.ops.preferences.asset_library_add(directory=str(root))
        libraries[-1].name=name
    bpy.ops.wm.save_userpref()
    print("ASSET_LIBRARY_REGISTERED",root)


if __name__=="__main__":
    cli=argparse.ArgumentParser()
    cli.add_argument("root",type=Path)
    cli.add_argument("--register",action="store_true")
    cli.add_argument("--register-only",action="store_true")
    cli.add_argument("--rebuild-candidates",action="store_true")
    args=cli.parse_args(sys.argv[sys.argv.index("--")+1:])
    for name in CATEGORIES:
        (args.root/name).mkdir(parents=True,exist_ok=True)
    if not args.register_only:
        manifest=args.root/"asset_manifest.json"
        candidates=[args.root/fields[0]/(key+".blend") for key,fields in ASSETS.items()]
        existing=any(path.exists() for path in candidates)
        if existing and not args.rebuild_candidates:
            cli.error("Asset files already exist. Use a new library root or explicitly rebuild candidates.")
        if existing and not manifest.is_file():
            cli.error("An existing library requires a manifest before rebuilding.")
        if manifest.is_file():
            data=json.loads(manifest.read_text(encoding="utf-8"))
            if any(a["id"] in ASSETS and a["status"]=="Production Ready" for a in data["assets"]):
                cli.error("Production assets are immutable. Use a new library root for the revision.")
        stage_kit(args.root)
    if args.register or args.register_only:
        register(args.root)
