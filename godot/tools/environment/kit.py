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
    "wall": ("Architecture", "Ashlar Wall", "4 m bays with independently bonded faces over a mortar core. Origin at the base center.", ["masonry", "ruin", "retaining"]),
    "arch": ("Architecture", "Vaulted Gateway", "2.68 m clear opening. Full-depth voussoirs with cut-to-curve spandrel courses. Origin at threshold center.", ["ruin", "gateway", "masonry"]),
    "stairs": ("Architecture", "Limestone Stair", "3.6 m-wide route. Nine 0.18 m risers and 0.34 m treads. Origin at first riser.", ["elevation", "masonry", "terrace"]),
    "cliff": ("Terrain", "Faulted Limestone Escarpment", "Continuous sedimentary bench with dipping strata, eroded joints and a foundation shelf. Local Z=0 at the foot.", ["cliff", "terrain", "ruin"]),
    "limestone": ("Materials", "Honed Limestone", "Image-backed pale cut-stone finish. 1.35 m UV repeat for architectural modules.", ["stone", "pbr", "masonry"]),
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


def tone_stone():
    return rng.choices(stone_palette, weights=(61, 23, 16), k=1)[0]


def face_stone(part, mat, x0, x1, z0, z1, front, back, chip=.032):
    """Cut a lightly battered stone's elevation, including its visible corner facets."""
    size=min(chip, (x1-x0)*.18, (z1-z0)*.18)
    a,b,c,d=[size*rng.uniform(.43,1.17) for _ in range(4)]
    skew=rng.uniform(-.015,.015)
    profile=[(x0+a,z0),(x1-b,z0+rng.uniform(-.003,.003)),(x1,z0+b),
             (x1+skew,z1-c),(x1-c+skew,z1),(x0+d+skew,z1),
             (x0+skew,z1-d),(x0,z0+a)]
    profile=[(max(x0,min(x1,x)),z) for x,z in profile]
    solid(part,mat,profile,front,back,vertical=True,tone=rng.random())


def bond(x0, x1, widths):
    """Yield full-width courses without narrow closing slivers."""
    x=x0
    for width in widths:
        end=min(x1,x+width)
        if x1-end<.20:
            end=x1
        yield x,end
        if end==x1:
            return
        x=end


def wall():
    # Each face has its own bond. Rotating a bay reverses its appearance without changing its socket.
    block("Recessed lime joints and hearting",mortar,-1.998,1.998,-.257,.257,.10,1.96,.014)
    levels=(.14,.474,.712,1.019,1.229,1.562,1.819,1.946)
    firsts=((.51,1.06,.37,.84,.62,1.18,.35),(.96,.44,.75,.43,1.21,.48,.79))
    for sign,first in zip((-1,1),firsts):
        for row,(lo,hi) in enumerate(zip(levels,levels[1:])):
            widths=[first[row]]+[rng.uniform(.43,1.14) for _ in range(16)]
            for x0,x1 in bond(-2,2,widths):
                lip=rng.uniform(.009,.031)+(.009 if row in (0,4) else 0)
                front,back=sorted((sign*(.263+lip),sign*.204))
                face_stone("Independent ashlar face courses",tone_stone(),
                           x0+.0045,x1-.0045,lo+.0045,hi-.0045,front,back,
                           chip=.020 if row==6 else .035)
    for n,(z,width,h) in enumerate(((0,.744,.14),(.131,.656,.074),(1.867,.635,.098),(1.972,.754,.128))):
        for a,b in bond(-2,2,[(.64,1.09,.83,1.03)[n]]+[rng.uniform(.73,1.34) for _ in range(10)]):
            block("Offset plinths and water-shedding caps",tone_stone(),a+.005,b-.005,-width/2,width/2,
                  z,z+h,.022,rng.random())


def arch():
    spring,inside,ring = 1.91,1.34,1.735
    levels=(.14,.474,.712,1.019,1.229,1.562,1.819,2.060,2.321,2.562,2.824,3.062,3.345,3.582,3.705)

    def cut_radius(z,rad):
        return math.sqrt(max(0,rad**2-max(0,z-spring)**2))

    def haunch(sign,low,high,rad,low_bound,high_bound):
        # Sample the curved cut densely around the crown; the remaining edges are straight bed joints.
        steps=max(3,math.ceil((high-low)/.058))
        zs=[low+(high-low)*i/steps for i in range(steps+1)]
        inner=[(sign*max(low_bound,cut_radius(z,rad)),z) for z in zs]
        points=inner+[(sign*high_bound,high),(sign*high_bound,low)]
        return points if sign<0 else points[::-1]

    for sign in (-1,1):
        backing=haunch(sign,.09,3.69,inside+.018,0,2.347)
        solid("Bonded gateway body and lime joints",mortar,backing,-.331,.331,True)
        for n,(low,high) in enumerate(zip(levels,levels[1:])):
            exposed=inside+.014 if high<=spring else ring-.022
            # The apparent seams below the spring align with the adjoining wall.
            minimum=cut_radius(high-.004,exposed)
            split=max(minimum+.20,1.885 if n%2==0 else 2.10)
            widths=[max(.19,split-minimum)]+[rng.uniform(.53,.90) for _ in range(5)]
            for a,b in bond(minimum,2.35,widths):
                if b<cut_radius(high-.004,exposed)+.07:
                    continue
                # Avoid collapsed inside edges where a horizontal course meets the ring.
                lo=low+.004
                if a<exposed and lo>spring:
                    z_hit=spring+math.sqrt(max(0,exposed**2-(b-.034)**2))
                    lo=max(lo,z_hit)
                if lo>high-.060:
                    continue
                contour=haunch(sign,lo,high-.004,exposed,a+.004,b-.004)
                depth=.346 if n>6 else .35
                depth+=rng.uniform(-.007,.011)
                a_mat=tone_stone()
                solid("Coursed jambs and cut spandrels",a_mat,contour,-depth,depth,True,tone=rng.random())
        bed0,bed1=sorted((sign*1.351,sign*1.642))
        block("Jamb bedding behind dressings",mortar,bed0,bed1,-.405,.405,.19,1.837,.006)
        lo,hi=sorted((sign*1.29,sign*1.80))
        for a,b,z0,z1,y in ((lo-.08,hi+.08,0,.132,.475),(lo,hi,.129,.23,.432),
                             (lo-.028,hi+.04,1.746,1.846,.458),
                             (lo-.050,hi+.073,1.84,1.931,.489)):
            block("Jamb plinths and bearing imposts",tone_stone(),a,b,-y,y,z0,z1,.022,rng.random())
        for i,(z0,z1) in enumerate(zip(levels[:7],levels[1:8])):
            head=min(z1-.005,1.831)
            if head-z0<.024:
                continue
            a,b=sorted((sign*1.347,sign*(1.541+(i%3)*.052)))
            face_stone("Through jamb dressings",stone,a,b,z0+.005,head,-.423,.423,.018)

    def arc(rad0,rad1,a,b):
        steps=4
        angles=[a+(b-a)*j/steps for j in range(steps+1)]
        return [(r*math.cos(t),spring+r*math.sin(t))
                for r,seq in ((rad1,angles),(rad0,angles[::-1])) for t in seq]

    # One full-depth barrel. A slightly recessed mortar arc closes the hairline beds.
    for i in range(17):
        a,b=i*math.pi/17,(i+1)*math.pi/17
        solid("Recessed vault joints",mortar,arc(inside+.010,ring-.018,a,b),-.351,.351,True)
        key=.042 if i==8 else 0
        face=tone_stone()
        solid("Full-depth bearing voussoirs",face,arc(inside,ring+key,a+.0028,b-.0028),
              -.487,.487,True,rng.random())
        solid("Worked inner arris",face,arc(inside+.018,inside+.108,a+.003,b-.003),
              -.513,.512,True,rng.random())
        solid("Bevelled outer header band",face,arc(ring-.087,ring+key+.021,a+.0028,b-.0028),
              -.506,.506,True,rng.random())
    for z,w,h in ((3.674,.704,.109),(3.78,.882,.14)):
        for a,b in bond(-2.20,2.20,[.61]+[rng.uniform(.65,1.11) for _ in range(9)]):
            block("Bonded crown caps",tone_stone(),a+.005,b-.005,-w/2,w/2,z,z+h,.025,rng.random())


def stairs():
    for i in range(9):
        z=(i+1)*.18
        y=i*.34
        seams=(-1.8,-.91+rng.uniform(-.12,.12),.24+rng.uniform(-.34,.35),
               1.11+rng.uniform(-.12,.13),1.8)
        for a,b in zip(seams,seams[1:]):
            block("Seated tread blocks",tone_stone(),a+.0028,b-.0028,y-.027,y+.344,
                  z-.182,z,.011,rng.random())
        block("Continuous stair bed",mortar,-1.798,1.798,y-.006,y+.345,-.08,z-.006,.01)
    for sign in (-1,1):
        a,b=sorted((sign*1.79,sign*2.215))
        anchors=[(-.075,.270),(.26,.375),(2.84,1.736),(3.055,1.755)]
        def rise(y):
            return min(1.755,max(.27,.27+y*.508))
        solid("Load-bearing cheek core",mortar,[(-.065,-.085),(3.056,-.085),
                                               (3.056,1.745),(-.065,.254)],a+.015,b-.015,side=True)
        for row in range(7):
            low=-.066+row*.25
            hi=low+.242
            start=max(-.058,(low-.27)/.508+.04)
            if start>=3.046:
                continue
            for y0,y1 in bond(start,3.05,[.31+(.24 if row%2 else 0)]+[rng.uniform(.44,.73) for _ in range(9)]):
                y0,y1=y0+.005,y1-.005
                outline=[(y0,low),(y1,low),(y1,min(hi,rise(y1))),(y0,min(hi,rise(y0)))]
                solid("Dressed raking cheek courses",tone_stone(),outline,a,b,side=True,tone=rng.random())
        for (start,z0),(end,z1) in zip(anchors,anchors[1:]):
            m=(z1-z0)/(end-start)
            for y0,y1 in bond(start,end,[.45]+[rng.uniform(.46,.70) for _ in range(12)]):
                y0,y1=y0+.003,y1-.003
                lo0,lo1=z0+m*(y0-start)-.011,z0+m*(y1-start)-.011
                reverse=[(y0,lo0),(y1,lo1),(y1,lo1+.107),(y0,lo0+.107)]
                solid("Raking cap and level returns",tone_stone(),reverse,a-.039,b+.039,side=True,tone=rng.random())
        block("Landing abutment",tone_stone(),a-.015,b+.015,2.94,3.088,1.42,1.752,.020,.5)


def cliff():
    """Build one closed bench with dipping beds around its entire perimeter."""
    # The outline places an eroded apron in front of the upper foundation shelf.
    outline=[(-3.36,-1.08),(-3.13,-2.16),(-2.20,-2.66),(-.92,-2.57),
             (.26,-2.59),(1.15,-2.85),(2.56,-2.50),(3.36,-1.62),(3.44,-.55),
             (3.29,.56),(2.91,1.73),(1.55,2.40),(.32,2.66),(-.85,2.53),
             (-2.10,2.57),(-3.15,1.94),(-3.39,.82)]
    bands=((0,.965),(.20,.976),(.32,.979),(.49,.956),(.73,.954),(.81,.966),
           (.98,.957),(1.34,.945),(1.47,.962),(1.53,.937),(1.75,.930),
           (1.95,.927),(2.24,.913),(2.30,.901),(2.49,.856),(2.68,.826),
           (2.81,.794),(3.01,.770),(3.20,.720),(3.27,.659))
    verts, faces, tones=groups[("Continuous jointed bedrock",rock)]
    rim=[]
    anchor=len(verts)
    for index,p in enumerate(outline):
        a,b=Vector(p),Vector(outline[(index+1)%len(outline)])
        for i in range(4):
            t=i/4
            q=a.lerp(b,t)
            rim.append((q.x,q.y,.66*math.sin(len(rim)*1.93)+.34*rng.uniform(-1,1)))
    n=len(rim)
    for j,(height,scale) in enumerate(bands):
        for i,(x,y,seed) in enumerate(rim):
            r=Vector((x,y)).normalized()
            seam=.074*seed+.076*math.sin(i*.39+j*.17)+.038*rng.uniform(-1,1)
            # Joint runs taper and stop. The inherited beds continue across the unbroken rock.
            seam+=.072*math.sin(j*1.31)*max(0,math.sin(i*.112+j*.128))
            seam-=.131 if i in (5,21,28,49,59) and 4<j<18 else 0
            dip=.17*math.sin(x*.69+y*.35)+.039*x-.049*y
            expose=math.sin(math.pi*min(height,3.27)/3.27)
            shelf=max(0,(height-2.02)/1.25)
            erosion=(.13+.22*math.sin(x*.82-y*.53)+.15*math.cos(y*1.27+x*.66))*shelf
            z=height+dip*expose+.026*seed+.015*rng.uniform(-1,1)-max(0,erosion)
            verts.append((x*scale+r.x*seam+.20*height/3.27,
                          y*scale+r.y*seam+.15*height/3.27,max(0,z)*.87))
    for j in range(len(bands)-1):
        start=anchor+j*n
        for i in range(n):
            k=(i+1)%n
            p,q,r,t=start+i,start+k,start+n+k,start+n+i
            faces.extend(((p,q,t),(q,r,t)) if (i+j)%2 else ((p,q,r),(p,r,t)))
            tones.extend((0,0))
    top=anchor+(len(bands)-1)*n
    verts.append((.12,.08,2.71))
    for i in range(n):
        faces.append((top+i,top+(i+1)%n,len(verts)-1))
        tones.append(0)
    faces.append(tuple(anchor+i for i in reversed(range(n))))
    tones.append(0)


def terrace():
    block("Set paving bed",mortar,-3.156,3.156,-2.16,2.16,-.61,-.067,.10)
    plate=((-3.22,-1.80),(-2.91,-2.20),(2.93,-2.20),(3.24,-1.80),
           (3.24,1.82),(2.99,2.20),(-2.95,2.20),(-3.22,1.90))
    for face_y in (-2.125, 2.125):
        masonry(-3.03,3.03,face_y-.11,face_y+.11,-.64,2,.279)
    for face_x in (-3.11,3.11):
        for y in (-1.62,-.81,0,.81,1.62):
            block("Bonded court foundations",tone_stone(),face_x-.12,face_x+.12,y-.396,y+.397,-.64,-.089,.033,rng.random())
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
            block("Staggered limestone flagstones",tone_stone(),x+.009,limit-.009,y,y+.482,-.035,
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
            offset=round(tone*167)/17 if mat in stone_palette else 0
            for idx in p.loop_indices:
                position=verts[mesh.loops[idx].vertex_index]
                uv.data[idx].uv=(position[a]*flip/repeat+offset,position[b]/repeat+offset*.43)
        if mat in stone_palette:
            bevel=obj.modifiers.new("Mason-dressed edges","BEVEL")
            bevel.width=.011 if part=="Independent ashlar face courses" else .0085
            bevel.segments=1
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
    global stone,rock,paving,mortar,stone_palette
    textures=root/"Materials"/"Textures"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system="METRIC"
    stone=material("Honed Limestone",textures/"Limestone",{"Base Color":"color.jpg","Roughness":"roughness.jpg","Normal":"normal.jpg"},1.35,(.63,.57,.44),.88)
    shared={"Roughness":"roughness.jpg","Normal":"normal.jpg"}
    honey=material("Ochre-bearing limestone",textures/"Limestone",{"Base Color":"ochre.jpg",**shared},1.35,strength=.88)
    gray=material("Cool-bedded limestone",textures/"Limestone",{"Base Color":"cool.jpg",**shared},1.35,strength=.88)
    mortar=material("Recessed lime mortar",textures/"Limestone",{"Base Color":"mortar.jpg",**shared},1.08,strength=.37)
    stone_palette=(stone,honey,gray)
    rock=material("Weathered Escarpment",textures/"Rock051",{"Base Color":"Rock051_1K-JPG_Color.jpg","Roughness":"Rock051_1K-JPG_Roughness.jpg","Normal":"Rock051_1K-JPG_NormalGL.jpg"},2.2,(.36,.34,.30),.70)
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
