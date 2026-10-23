"""Build the NiteLite bedroom in Blender and render it.

Run headless from the repo root:

    BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
    $BLENDER -b --factory-startup --disable-autoexec -P scene/build_scene.py -- \
        --state day --out scene/renders/day.png [--samples 128] [--width 1920] [--save]

States
    day    Light mode: sunny morning through the window, lamp off.
    night  Dark mode: moonlight, the bedside lamp (the night light) on.

Coordinates are metres, Z up. The back wall's inner face is y = 2.0, the right
wall (with the window) is x = 2.6, the floor is z = 0. The camera looks in
from the front-left. Assets come from scene/fetch_assets.py.
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "assets")

ROOM = dict(x0=-2.8, x1=2.6, y0=-3.6, y1=2.0, h=2.6, wall_t=0.15)
WINDOW = dict(y0=0.25, y1=1.55, z0=0.85, z1=2.2)  # opening in the right wall
DOOR = dict(x0=-2.62, x1=-1.86, h=2.05)           # opening in the back wall
BED = dict(cx=0.25, w=1.6, len=2.05)
NIGHTSTAND = (1.45, 1.72)


# ---------------------------------------------------------------- helpers

def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--state", choices=["day", "night"], default="day")
    p.add_argument("--out", default=os.path.join(HERE, "renders", "still.png"))
    p.add_argument("--samples", type=int, default=128)
    p.add_argument("--width", type=int, default=1920)
    p.add_argument("--height", type=int, default=0, help="defaults to 16:9")
    p.add_argument("--save", action="store_true", help="also save scene/room.blend")
    p.add_argument("--cam", choices=sorted(CAMERAS), default="wide")
    return p.parse_args(argv)


def link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj)
    return obj


def mesh_obj(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    if mat:
        ob.data.materials.append(mat)
    return ob


def box(name, x0, x1, y0, y1, z0, z1, mat=None, bevel=0.0, segments=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(((x0 + x1) / 2 + v.co.x * (x1 - x0), (y0 + y1) / 2 + v.co.y * (y1 - y0), (z0 + z1) / 2 + v.co.z * (z1 - z0)))
    ob = mesh_obj(name, bm, mat)
    if bevel:
        m = ob.modifiers.new("Bevel", "BEVEL")
        m.width, m.segments, m.limit_method = bevel, segments, "ANGLE"
        m.harden_normals = True
    smooth(ob)
    return ob


def smooth(ob, angle=35):
    """Smooth shading, but keep edges sharper than `angle` crisp. Without the sharp
    edges a box's faces shade as one rounded blob, which shows up as bright
    gradient wedges on walls and ceilings."""
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.set_sharp_from_angle(angle=math.radians(angle))


def lathe(name, profile, mat=None, steps=64):
    """Revolve (radius, z) points around Z."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0, z)) for r, z in profile]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    ob = mesh_obj(name, bm, mat)
    m = ob.modifiers.new("Screw", "SCREW")
    m.steps = m.render_steps = steps
    m.use_merge_vertices = True
    m.use_smooth_shade = True
    return ob


def import_gltf(name, loc, rot_z=0.0, scale=1.0):
    path = os.path.join(ASSETS, "models", name, f"{name}.gltf")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    root = link(bpy.data.objects.new(f"{name}_root", None))
    for o in new:
        if o.parent is None:
            o.parent = root
    root.location = loc
    root.rotation_euler = (0, 0, math.radians(rot_z))
    root.scale = (scale,) * 3
    return root, new


# ---------------------------------------------------------------- materials

def node_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    return m, nt, bsdf


def tex(nt, path, coord, non_color=False, scale=1.0):
    img = bpy.data.images.load(path, check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = img
    n.projection = "BOX"
    n.projection_blend = 0.25
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    nt.links.new(coord, mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
    return n


def pbr(name, texture, scale=1.0, tint=None, rough_mult=1.0, bump=0.3, sheen=0.0):
    """Box-projected texture set (no UVs needed). tint multiplies the diffuse map."""
    m, nt, bsdf = node_mat(name)
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    d = os.path.join(ASSETS, "textures", texture)
    if os.path.exists(os.path.join(d, "Diffuse.jpg")):
        col = tex(nt, os.path.join(d, "Diffuse.jpg"), coord, scale=scale).outputs["Color"]
        if tint:
            # Keep only the texture's light/dark detail, then colour it
            bw = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(col, bw.inputs["Color"])
            lift = nt.nodes.new("ShaderNodeMapRange")
            lift.inputs["To Min"].default_value = 0.55
            lift.inputs["To Max"].default_value = 1.15
            nt.links.new(bw.outputs["Val"], lift.inputs["Value"])
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            mix.inputs["A"].default_value = (1, 1, 1, 1)
            nt.links.new(lift.outputs["Result"], mix.inputs["A"])
            mix.inputs["B"].default_value = (*tint, 1)
            col = mix.outputs["Result"]
        nt.links.new(col, bsdf.inputs["Base Color"])
    elif tint:
        bsdf.inputs["Base Color"].default_value = (*tint, 1)
    rough = tex(nt, os.path.join(d, "Rough.jpg"), coord, non_color=True, scale=scale)
    if rough_mult != 1.0:
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = rough_mult
        nt.links.new(rough.outputs["Color"], mul.inputs[0])
        nt.links.new(mul.outputs[0], bsdf.inputs["Roughness"])
    else:
        nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    if bump:
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        b.inputs["Distance"].default_value = 0.002
        nt.links.new(rough.outputs["Color"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    if sheen:
        bsdf.inputs["Sheen Weight"].default_value = sheen
    return m


def flat(name, color, rough=0.5, metal=0.0, coat=0.0):
    m, nt, bsdf = node_mat(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Coat Weight"].default_value = coat
    return m


def emissive(name, color, strength):
    m, nt, bsdf = node_mat(name)
    bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def image_mat(name, path):
    m, nt, bsdf = node_mat(name)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.abspath(path))
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def linen_shade(name):
    """Translucent fabric lampshade: light glows through it."""
    m, nt, bsdf = node_mat(name)
    out = nt.nodes["Material Output"]
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    d = os.path.join(ASSETS, "textures", "rough_linen")
    col = tex(nt, os.path.join(d, "Diffuse.jpg"), coord, scale=6)
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type, tint.blend_type = "RGBA", "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs["B"].default_value = (1.0, 0.93, 0.8, 1)
    nt.links.new(col.outputs["Color"], tint.inputs["A"])
    nt.links.new(tint.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    tr = nt.nodes.new("ShaderNodeBsdfTranslucent")
    tr.inputs["Color"].default_value = (1.0, 0.85, 0.62, 1)
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 0.55
    nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
    nt.links.new(tr.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return m


# ---------------------------------------------------------------- the room

def build_room(M):
    r = ROOM
    t = r["wall_t"]
    box("Floor", r["x0"] - t, r["x1"] + t, r["y0"], r["y1"] + t, -0.05, 0.0, M["floor"])
    box("Ceiling", r["x0"] - t, r["x1"] + t, r["y0"], r["y1"] + t, r["h"], r["h"] + 0.1, M["ceiling"])
    box("WallLeft", r["x0"] - t, r["x0"], r["y0"], r["y1"] + t, 0, r["h"], M["wall"])
    box("WallFront", r["x0"] - t, r["x1"] + t, r["y0"] - t, r["y0"], 0, r["h"], M["wall"])

    # Back wall with a door opening
    y0, y1 = r["y1"], r["y1"] + t
    d = DOOR
    box("WallBackL", r["x0"] - t, d["x0"], y0, y1, 0, r["h"], M["wall"])
    box("WallBackR", d["x1"], r["x1"] + t, y0, y1, 0, r["h"], M["wall"])
    box("WallBackDoorHead", d["x0"], d["x1"], y0, y1, d["h"], r["h"], M["wall"])

    # Right wall with a window opening
    x0, x1 = r["x1"], r["x1"] + t
    w = WINDOW
    box("WallRightA", x0, x1, r["y0"], w["y0"], 0, r["h"], M["wall"])
    box("WallRightB", x0, x1, w["y1"], r["y1"] + t, 0, r["h"], M["wall"])
    box("WallRightBelow", x0, x1, w["y0"], w["y1"], 0, w["z0"], M["wall"])
    box("WallRightAbove", x0, x1, w["y0"], w["y1"], w["z1"], r["h"], M["wall"])

    # Ground outside. Puresky HDRIs are bright below the horizon, and without
    # something out there that light shines *up* through the window and paints
    # a hard wedge on the ceiling.
    box("Ground", r["x1"] + t, 3000, -3000, 3000, -0.6, -0.5, M["ground"])

    # Skirting boards
    box("SkirtBackL", r["x0"], d["x0"] - 0.06, y0 - 0.015, y0, 0, 0.1, M["trim"], bevel=0.004)
    box("SkirtBackR", d["x1"] + 0.06, r["x1"], y0 - 0.015, y0, 0, 0.1, M["trim"], bevel=0.004)
    box("SkirtRight", x0 - 0.015, x0, r["y0"], r["y1"], 0, 0.1, M["trim"], bevel=0.004)
    box("SkirtLeft", r["x0"], r["x0"] + 0.015, r["y0"], r["y1"], 0, 0.1, M["trim"], bevel=0.004)


def build_window(M):
    """Frame, sill, glazing bars and venetian blinds in the right wall."""
    w, x = WINDOW, ROOM["x1"]
    t = ROOM["wall_t"]
    f = 0.05
    # Reveal lining and frame
    box("WinSill", x - 0.06, x + t, w["y0"] - 0.05, w["y1"] + 0.05, w["z0"] - 0.03, w["z0"], M["trim"], bevel=0.005)
    box("WinFrameTop", x + 0.04, x + 0.1, w["y0"], w["y1"], w["z1"] - f, w["z1"], M["trim"])
    box("WinFrameBot", x + 0.04, x + 0.1, w["y0"], w["y1"], w["z0"], w["z0"] + f, M["trim"])
    box("WinFrameL", x + 0.04, x + 0.1, w["y0"], w["y0"] + f, w["z0"], w["z1"], M["trim"])
    box("WinFrameR", x + 0.04, x + 0.1, w["y1"] - f, w["y1"], w["z0"], w["z1"], M["trim"])
    ym = (w["y0"] + w["y1"]) / 2
    box("WinMullion", x + 0.05, x + 0.09, ym - 0.02, ym + 0.02, w["z0"], w["z1"], M["trim"])
    zm = w["z0"] + (w["z1"] - w["z0"]) * 0.62
    box("WinTransom", x + 0.05, x + 0.09, w["y0"], w["y1"], zm - 0.02, zm + 0.02, M["trim"])

    # Venetian blinds: slats inside the reveal, tilt animated via the parent empty's custom prop
    blinds = link(bpy.data.objects.new("Blinds", None))
    blinds["tilt"] = 0.0
    n = 26
    top, bottom = w["z1"] - 0.08, w["z0"] + 0.06
    head = box("BlindsHead", x + 0.005, x + 0.04, w["y0"] + 0.02, w["y1"] - 0.02, top, top + 0.04, M["blind"], bevel=0.004)
    head.parent = blinds
    for i in range(n):
        z = top - 0.04 - i * (top - bottom) / n
        s = box(f"Slat{i:02d}", -0.0125, 0.0125, w["y0"] + 0.025, w["y1"] - 0.025, -0.0006, 0.0006, M["blind"])
        s.location = (x + 0.022, 0, z)
        s.parent = blinds
        s["slat"] = True
    return blinds


def set_blinds(blinds, tilt_deg, frame=None, interp="BEZIER"):
    for c in blinds.children:
        if c.get("slat"):
            c.rotation_euler = (0, math.radians(tilt_deg), 0)
            key(c, "rotation_euler", frame, interp)


def curtain_mesh(name, width_flat, span, height, anchor, side, folds=7, nx=140, nz=40, mat=None):
    """Pleated curtain hanging from z=top, gathered over `span` metres from `anchor`.
    side=+1 extends toward +y, -1 toward -y. Fold depth grows as the curtain is gathered."""
    bm = bmesh.new()
    depth = math.sqrt(max(width_flat ** 2 - span ** 2, 0)) / (folds * 2.2)
    grid = []
    for j in range(nz + 1):
        v = j / nz
        row = []
        for i in range(nx + 1):
            u = i / nx
            phase = u * folds * 2 * math.pi
            flare = 1.0 + 0.25 * (1 - v)  # folds open up slightly toward the hem
            irregular = 1.0 + 0.18 * math.sin(u * 13.7 + 1.3)
            x = -abs(math.sin(phase / 2)) * depth * flare * irregular
            y = anchor + side * u * span
            z = v * height
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    ob = mesh_obj(name, bm, mat)
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.004
    smooth(ob)
    return ob


def build_curtains(M):
    """Two velvet curtains on a rod in front of the window. Open/closed are shape keys."""
    w, x = WINDOW, ROOM["x1"]
    top = w["z1"] + 0.18
    height = top - 0.02
    rod = box("CurtainRod", x - 0.13, x - 0.11, w["y0"] - 0.45, w["y1"] + 0.45, top + 0.02, top + 0.04, M["brass"])
    rod.modifiers.clear()
    curtains = []
    full = (w["y1"] - w["y0"]) / 2 + 0.45 + 0.06  # each closed curtain covers half the window plus overlap
    for side, anchor in ((+1, w["y0"] - 0.42), (-1, w["y1"] + 0.42)):
        open_span, closed_span = 0.36, full
        flat_w = closed_span * 1.6
        name = "CurtainL" if side > 0 else "CurtainR"
        ob = curtain_mesh(name, flat_w, open_span, height, anchor, side, mat=M["velvet"])
        ob.location = (x - 0.12, 0, 0.02)
        closed = curtain_mesh(name + "_closed", flat_w, closed_span, height, anchor, side)
        ob.shape_key_add(name="Open")
        k = ob.shape_key_add(name="Closed")
        for i, v in enumerate(closed.data.vertices):
            k.data[i].co = v.co
        bpy.data.objects.remove(closed)
        curtains.append(ob)
    return curtains


def set_curtains(curtains, closed, frame=None, interp="BEZIER"):
    for c in curtains:
        k = c.data.shape_keys.key_blocks["Closed"]
        k.value = closed
        key(k, "value", frame, interp)


def build_door(M):
    """Panel door in the back wall, hinged on its left edge, with a lit hallway behind."""
    d, y = DOOR, ROOM["y1"]
    t = ROOM["wall_t"]
    # Frame/architrave
    for nm, a, b in (("DoorCasingL", d["x0"] - 0.07, d["x0"]), ("DoorCasingR", d["x1"], d["x1"] + 0.07)):
        box(nm, a, b, y - 0.02, y + 0.005, 0, d["h"] + 0.07, M["trim"], bevel=0.004)
    box("DoorCasingTop", d["x0"] - 0.07, d["x1"] + 0.07, y - 0.02, y + 0.005, d["h"], d["h"] + 0.07, M["trim"], bevel=0.004)
    box("DoorLining", d["x0"], d["x1"], y, y + t, d["h"], d["h"] + 0.01, M["trim"])

    hinge = link(bpy.data.objects.new("DoorHinge", None))
    hinge.location = (d["x0"] + 0.01, y + 0.04, 0)
    wdt = d["x1"] - d["x0"] - 0.02
    leaf = box("DoorLeaf", 0, wdt, -0.02, 0.02, 0.005, d["h"] - 0.005, M["door"], bevel=0.003)
    leaf.parent = hinge
    for i, (z0, z1) in enumerate(((0.12, 0.95), (1.08, 1.9))):
        p = box(f"DoorPanel{i}", 0.1, wdt - 0.1, -0.026, -0.018, z0, z1, M["door"], bevel=0.008)
        p.parent = hinge
    knob = lathe("DoorKnob", [(0, 0), (0.012, 0), (0.012, 0.04), (0.03, 0.05), (0.032, 0.07), (0.0, 0.075)], M["brass"])
    knob.rotation_euler = (math.radians(90), 0, 0)
    knob.location = (wdt - 0.07, -0.02, 0.98)
    knob.parent = hinge

    # Hallway: a small lit box behind the door
    hy0, hy1 = y + t, y + t + 1.4
    box("HallFloor", d["x0"] - 0.6, d["x1"] + 0.6, hy0, hy1, -0.05, 0, M["floor"])
    box("HallBack", d["x0"] - 0.6, d["x1"] + 0.6, hy1, hy1 + 0.1, 0, ROOM["h"], M["hall"])
    box("HallSideL", d["x0"] - 0.7, d["x0"] - 0.6, hy0, hy1, 0, ROOM["h"], M["hall"])
    box("HallSideR", d["x1"] + 0.6, d["x1"] + 0.7, hy0, hy1, 0, ROOM["h"], M["hall"])
    box("HallCeiling", d["x0"] - 0.7, d["x1"] + 0.7, hy0, hy1 + 0.1, ROOM["h"], ROOM["h"] + 0.1, M["hall"])
    light = bpy.data.lights.new("HallLight", "AREA")
    light.shape, light.size, light.size_y = "RECTANGLE", 0.6, 0.3
    light.color = (1.0, 0.78, 0.52)
    ob = link(bpy.data.objects.new("HallLight", light))
    ob.location = ((d["x0"] + d["x1"]) / 2, (hy0 + hy1) / 2, ROOM["h"] - 0.05)
    return hinge, light


def drape(name, width, length, top, half, foot_y, head_y, cx, drop, mat, thick=0.03, noise=0.012, res=0.02):
    """A blanket lying over a box (half-width `half`, top at `top`), hanging `drop` over the sides and foot."""
    bm = bmesh.new()
    nx, ny = int(width / res), int(length / res)
    rad = 0.06
    grid = []
    for j in range(ny + 1):
        row = []
        y = head_y - j * length / ny
        for i in range(nx + 1):
            x = -width / 2 + i * width / nx
            ox = max(abs(x) - half, 0.0)
            oy = max(foot_y - y, 0.0)
            # Bend over the edges with a rounded corner, then hang straight down
            def bend(o):
                if o <= 0:
                    return 0.0, 0.0
                if o < rad * math.pi / 2:
                    a = o / rad
                    return rad * math.sin(a), rad * (1 - math.cos(a))
                return rad, rad + (o - rad * math.pi / 2)
            bx, bz = bend(ox)
            byy, bzz = bend(oy)
            px = cx + math.copysign(min(abs(x), half) + bx, x)
            py = y if oy <= 0 else foot_y - byy
            pz = top - max(bz, bzz)
            pz = max(pz, top - drop)
            row.append(bm.verts.new((px, py, pz)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    ob = mesh_obj(name, bm, mat)
    tx = bpy.data.textures.new(name + "Wrinkles", "CLOUDS")
    tx.noise_scale = 0.18
    disp = ob.modifiers.new("Wrinkles", "DISPLACE")
    disp.texture, disp.strength, disp.mid_level = tx, noise, 0.5
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    sub = ob.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = sub.render_levels = 1
    smooth(ob)
    return ob


def build_bed(M):
    b = BED
    x0, x1 = b["cx"] - b["w"] / 2, b["cx"] + b["w"] / 2
    yh = ROOM["y1"] - 0.08
    yf = yh - b["len"]
    box("BedBase", x0, x1, yf, yh, 0.16, 0.36, M["bedframe"], bevel=0.008)
    for lx in (x0 + 0.06, x1 - 0.06):
        for ly in (yf + 0.06, yh - 0.06):
            lathe(f"BedLeg", [(0, 0), (0.018, 0), (0.026, 0.16), (0, 0.16)], M["bedframe"]).location = (lx, ly, 0)
    box("Headboard", x0 - 0.06, x1 + 0.06, yh, yh + 0.07, 0.3, 1.22, M["headboard"], bevel=0.035, segments=6)
    mat_top = 0.6
    box("Mattress", x0 + 0.03, x1 - 0.03, yf + 0.03, yh - 0.02, 0.36, mat_top, M["sheet"], bevel=0.05, segments=5)
    pillows = []
    for i, px in enumerate((b["cx"] - 0.37, b["cx"] + 0.37)):
        p = pillow(f"Pillow{i}", M["pillow"])
        p.location = (px, yh - 0.24, mat_top + 0.13)
        p.rotation_euler = (math.radians(-28), 0, math.radians(3 if i else -4))
        pillows.append(p)
    colliders = [bpy.data.objects[n] for n in ("BedBase", "Mattress", "Headboard", "Floor")] + pillows
    duvet = cloth("Duvet", M["duvet"], width=b["w"] + 0.55, length=1.75, center=(b["cx"], yf + 0.75), z=mat_top + 0.06,
                  colliders=colliders, thickness=0.035, frames=70)
    cloth("Throw", M["throw"], width=b["w"] + 0.45, length=0.6, center=(b["cx"] + 0.05, yf + 0.33), z=mat_top + 0.2,
          colliders=colliders + [duvet], thickness=0.015, frames=60, stiffness=8)

    # Rug under the foot of the bed
    box("RugBorder", b["cx"] - 1.25, b["cx"] + 1.25, yf - 0.75, yh - 0.6, 0.0, 0.012, M["rugBorder"], bevel=0.004)
    box("Rug", b["cx"] - 1.15, b["cx"] + 1.15, yf - 0.65, yh - 0.7, 0.0, 0.014, M["rug"], bevel=0.004)
    # Framed NiteLite icon print above the headboard
    art(M, b["cx"], ROOM["y1"] - 0.01, 1.72, 0.62)



def art(M, cx, y, cz, size):
    """Walnut frame with a cream mat and the app icon, hung on the back wall."""
    f = 0.03
    box("ArtFrame", cx - size / 2 - f, cx + size / 2 + f, y - 0.035, y, cz - size / 2 - f, cz + size / 2 + f, M["walnut"], bevel=0.004)
    box("ArtMat", cx - size / 2, cx + size / 2, y - 0.037, y - 0.035, cz - size / 2, cz + size / 2, M["mat"])
    s = size * 0.62
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((cx + x * s / 2, y - 0.038, cz + z * s / 2)) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    face = bm.faces.new(vs)
    for loop, (u, v) in zip(face.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv].uv = (u, v)
    mesh_obj("ArtPrint", bm, M["print"])


CACHE = os.path.join(HERE, "cache")


def cloth(name, mat, width, length, center, z, colliders, thickness, frames, stiffness=15, res=0.025):
    """Drop a sheet of cloth onto the bed and keep the settled shape.
    The settled vertex positions are cached in scene/cache/ (delete to re-simulate)."""
    nx, ny = int(width / res), int(length / res)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=nx, y_segments=ny, size=0.5)
    for v in bm.verts:
        v.co = Vector((center[0] + v.co.x * width, center[1] + v.co.y * length, z))
    ob = mesh_obj(name, bm, mat)
    key = f"{name}-{nx}x{ny}-{width:.2f}-{length:.2f}-{z:.2f}-{center[0]:.2f}-{center[1]:.2f}-{frames}-{stiffness}.npy"
    path = os.path.join(CACHE, key)
    import numpy as np
    if os.path.exists(path):
        co = np.load(path)
        ob.data.vertices.foreach_set("co", co.ravel())
    else:
        print("simulating", name)
        for c in colliders:
            col = c.modifiers.new("Collision", "COLLISION")
            c.collision.thickness_outer = 0.004
            c.collision.cloth_friction = 8
        mod = ob.modifiers.new("Cloth", "CLOTH")
        st = mod.settings
        st.quality = 8
        st.mass = 0.4
        st.tension_stiffness = st.compression_stiffness = st.shear_stiffness = stiffness
        st.bending_stiffness = 0.3
        st.air_damping = 2.0
        mod.collision_settings.distance_min = 0.006
        mod.collision_settings.use_self_collision = False
        mod.point_cache.frame_start, mod.point_cache.frame_end = 1, frames
        sc = bpy.context.scene
        for f in range(1, frames + 1):
            sc.frame_set(f)
        ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
        co = np.empty(len(ev.data.vertices) * 3, dtype=np.float32)
        ev.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        ob.modifiers.remove(mod)
        for c in colliders:
            c.modifiers.remove(c.modifiers["Collision"])
        sc.frame_set(1)
        ob.data.vertices.foreach_set("co", co.ravel())
        os.makedirs(CACHE, exist_ok=True)
        np.save(path, co)
    ob.data.update()
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness, sol.offset = thickness, 1.0
    sub = ob.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = sub.render_levels = 1
    smooth(ob, angle=80)
    return ob


def pillow(name, mat, w=0.33, d=0.22, h=0.1):
    """Superellipsoid: boxy outline, puffy middle, seams tapering to the edges."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        sx = math.copysign(abs(x) ** 0.35, x)
        sy = math.copysign(abs(y) ** 0.35, y)
        puff = 1.0 - 0.35 * (sx * sx + sy * sy) / 2
        v.co = Vector((sx * w, sy * d, z * h * puff))
    ob = mesh_obj(name, bm, mat)
    tx = bpy.data.textures.new(name + "Lumps", "CLOUDS")
    tx.noise_scale = 0.12
    disp = ob.modifiers.new("Lumps", "DISPLACE")
    disp.texture, disp.strength = tx, 0.012
    smooth(ob)
    return ob


def build_lamp(M):
    """The night light: ceramic base, linen shade, warm bulb and a bead pull chain."""
    lamp = link(bpy.data.objects.new("Lamp", None))
    nx, ny = NIGHTSTAND
    lamp.location = (nx - 0.06, ny + 0.06, 0.616)
    base = lathe("LampBase", [(0, 0), (0.075, 0), (0.08, 0.012), (0.06, 0.03), (0.095, 0.11), (0.09, 0.2),
                              (0.05, 0.27), (0.018, 0.29), (0.016, 0.31), (0.0, 0.31)], M["ceramic"])
    base.parent = lamp
    socket = lathe("LampSocket", [(0, 0.31), (0.016, 0.31), (0.018, 0.37), (0.0, 0.37)], M["brass"])
    socket.parent = lamp
    bulb = lathe("LampBulb", [(0, 0.37), (0.012, 0.37), (0.028, 0.4), (0.03, 0.42), (0.02, 0.45), (0.0, 0.455)], M["bulb"])
    bulb.parent = lamp
    shade = lathe("LampShade", [(0.175, 0.30), (0.115, 0.52)], M["shade"], steps=96)
    sol = shade.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.003
    shade.parent = lamp
    for z, r in ((0.30, 0.176), (0.52, 0.116)):
        rim = lathe("ShadeRim", [(r, z - 0.003), (r + 0.002, z), (r, z + 0.003)], M["brass"])
        rim.parent = lamp
    # Pull chain hanging from the socket, below the shade
    for i in range(14):
        bead = lathe("ChainBead", [(0, -0.002), (0.0022, 0), (0, 0.002)], M["brass"], steps=12)
        bead.location = (0.022, 0, 0.36 - i * 0.0065)
        bead.parent = lamp
    pull = lathe("ChainPull", [(0, -0.012), (0.004, -0.008), (0.006, 0), (0.004, 0.008), (0, 0.012)], M["brass"], steps=24)
    pull.location = (0.022, 0, 0.36 - 14 * 0.0065 - 0.01)
    pull.parent = lamp

    light = bpy.data.lights.new("LampLight", "POINT")
    light.shadow_soft_size = 0.02
    light.color = (1.0, 0.7, 0.42)
    ob = link(bpy.data.objects.new("LampLight", light))
    ob.parent = lamp
    ob.location = (0, 0, 0.415)
    return lamp, light


def build_props(M):
    nx, ny = NIGHTSTAND
    import_gltf("painted_wooden_nightstand", (nx, ny, 0), rot_z=0)
    clock, parts = import_gltf("alarm_clock_01", (nx + 0.14, ny - 0.12, 0.616), rot_z=-28)
    # Phone lying on the nightstand, screen up
    phone = box("Phone", -0.037, 0.037, -0.077, 0.077, 0, 0.008, M["phone"], bevel=0.006, segments=4)
    phone.location = (nx - 0.13, ny - 0.17, 0.617)
    phone.rotation_euler = (0, 0, math.radians(-12))
    screen = box("PhoneScreen", -0.033, 0.033, -0.072, 0.072, 0.0081, 0.0083, M["screen"])
    screen.parent = phone
    # Book under the lamp
    box("BookA", nx - 0.21, nx + 0.05, ny - 0.03, ny + 0.17, 0.616, 0.646, M["bookA"], bevel=0.004)

    # TV on a low mid-century stand between the door and the bed
    sx0, sx1, sy0, sy1 = -1.72, -0.72, ROOM["y1"] - 0.45, ROOM["y1"] - 0.03
    box("TVStand", sx0, sx1, sy0, sy1, 0.16, 0.52, M["walnut"], bevel=0.01)
    for lx in (sx0 + 0.06, sx1 - 0.06):
        for ly in (sy0 + 0.06, sy1 - 0.06):
            lathe("StandLeg", [(0, 0), (0.012, 0), (0.02, 0.16), (0, 0.16)], M["walnut"]).location = (lx, ly, 0)
    tv, _ = import_gltf("Television_01", (-1.37, ROOM["y1"] - 0.25, 0.52), rot_z=10)
    # 8mm projector on the floor, pointed at the wall above the TV (the iris clip uses it)
    proj, _ = import_gltf("filmstrip_projector_8mm", (-1.15, 0.35, 0.0), rot_z=185)
    import_gltf("standing_picture_frame_01", (1.62, ny + 0.12, 0.616), rot_z=-20)

    # The garden outside the right-hand window
    # Trees sit in the camera's view through the window but out of the sun's path
    import_gltf("island_tree_02", (10.0, 8.5, -0.5), rot_z=30, scale=2.4)
    import_gltf("island_tree_02", (19.0, 13.0, -0.5), rot_z=160, scale=2.2)
    for i, (gy, rz) in enumerate(((-2.5, 90), (0.2, 90), (2.9, 90))):
        import_gltf("shrub_01", (4.8, gy, -0.5), rot_z=rz, scale=2.6)
    import_gltf("potted_plant_02", (2.15, 1.65, 0), rot_z=40, scale=1.15)
    return clock, parts, screen, tv, proj


# ---------------------------------------------------------------- lighting and states

# Everything that differs between light mode (day) and dark mode (night)
STATES = {
    "day": dict(world=4.0, night=0.0, sun=7.0, sun_color=(1.0, 0.88, 0.72), sun_travel=(-0.78, 0.28, -0.42),
                fill=70.0, fill_color=(0.92, 0.95, 1.0), lamp=0.0, bulb=0.0, screen=0.0, hall=0.0, blinds=12.0),
    "night": dict(world=0.2, night=1.0, sun=0.3, sun_color=(0.5, 0.64, 1.0), sun_travel=(-0.7, 0.1, -0.55),
                  fill=1.0, fill_color=(0.45, 0.55, 1.0), lamp=26.0, bulb=40.0, screen=0.6, hall=18.0, blinds=38.0),
}


def world():
    """Day and night skies in one world, blended by the "Night" value (0 or 1)."""
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Generated"]
    envs = []
    for name, rot in (("kloofendal_48d_partly_cloudy_puresky", 200), ("qwantani_moonrise_puresky", 90)):
        env = nt.nodes.new("ShaderNodeTexEnvironment")
        env.image = bpy.data.images.load(os.path.join(ASSETS, "hdri", f"{name}.hdr"))
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Rotation"].default_value = (0, 0, math.radians(rot))
        nt.links.new(coord, mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], env.inputs["Vector"])
        envs.append(env)
    night = nt.nodes.new("ShaderNodeValue")
    night.name = "Night"
    sky = nt.nodes.new("ShaderNodeMix")
    sky.data_type = "RGBA"
    nt.links.new(night.outputs[0], sky.inputs["Factor"])
    nt.links.new(envs[0].outputs["Color"], sky.inputs["A"])
    nt.links.new(envs[1].outputs["Color"], sky.inputs["B"])
    # At night the moonrise sky still lights the room, but seen directly through
    # the window it read as daylight. Camera rays see a deep navy version instead.
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type, tint.blend_type = "RGBA", "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs["B"].default_value = (0.06, 0.09, 0.22, 1)
    nt.links.new(sky.outputs["Result"], tint.inputs["A"])
    cam_night = nt.nodes.new("ShaderNodeMath")
    cam_night.operation = "MULTIPLY"
    nt.links.new(nt.nodes.new("ShaderNodeLightPath").outputs["Is Camera Ray"], cam_night.inputs[0])
    nt.links.new(night.outputs[0], cam_night.inputs[1])
    pick = nt.nodes.new("ShaderNodeMix")
    pick.data_type = "RGBA"
    nt.links.new(cam_night.outputs[0], pick.inputs["Factor"])
    nt.links.new(sky.outputs["Result"], pick.inputs["A"])
    nt.links.new(tint.outputs["Result"], pick.inputs["B"])
    bg = nt.nodes["Background"]
    nt.links.new(pick.outputs["Result"], bg.inputs["Color"])
    return dict(world_strength=bg.inputs["Strength"], night=night.outputs[0])


def lights():
    """Sun/moon through the window, plus a soft fill from an implied second
    window behind the camera."""
    s = bpy.data.lights.new("Sun", "SUN")
    s.angle = math.radians(0.6)
    sun = link(bpy.data.objects.new("Sun", s))
    f = bpy.data.lights.new("Fill", "AREA")
    f.shape, f.size, f.size_y = "RECTANGLE", 2.5, 1.4
    fill = link(bpy.data.objects.new("Fill", f))
    fill.location = (0.2, ROOM["y0"] + 0.1, 1.6)
    fill.rotation_euler = (math.radians(-90), 0, 0)  # face into the room (+y)
    return dict(sun=sun, fill=fill)


def key(owner, path, frame, interp):
    if frame is None:
        return
    bpy.context.preferences.edit.keyframe_new_interpolation_type = interp
    owner.keyframe_insert(path, frame=frame)


def apply_state(state, refs, frame=None, interp="CONSTANT"):
    """Set every day/night value; with `frame`, also keyframe them there."""
    v = STATES[state]
    M = refs["M"]

    def put(owner, path, value):
        setattr(owner, path, value)
        key(owner, path, frame, interp)

    put(refs["world_strength"], "default_value", v["world"])
    put(refs["night"], "default_value", v["night"])
    sun = refs["sun"]
    put(sun.data, "energy", v["sun"])
    put(sun.data, "color", v["sun_color"])
    # A sun lamp shines along its local -Z
    put(sun, "rotation_euler", (-Vector(v["sun_travel"]).normalized()).to_track_quat("Z", "Y").to_euler())
    put(refs["fill"].data, "energy", v["fill"])
    put(refs["fill"].data, "color", v["fill_color"])
    put(refs["lamp_light"], "energy", v["lamp"])
    put(refs["hall"], "energy", v["hall"])
    for mat, val in ((M["bulb"], v["bulb"]), (M["screen"], v["screen"])):
        put(mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"], "default_value", val)
    set_blinds(refs["blinds"], v["blinds"], frame, interp)
    set_curtains(refs["curtains"], 0.0, frame, interp)
    put(refs["door"], "rotation_euler", (0, 0, math.radians(-18)))


# name: (location, look-at target, focal length mm)
CAMERAS = {
    "wide": ((-0.35, -2.75, 1.25), (0.05, 1.6, 0.92), 24),
    "corner": ((-1.9, -1.6, 1.15), (0.9, 1.5, 0.85), 26),
    "nightstand": ((-0.2, -0.6, 1.05), (1.35, 1.7, 0.78), 35),
    "low": ((0.9, -2.4, 0.55), (0.3, 1.6, 1.0), 22),
}


def camera(name):
    loc, target, lens = CAMERAS[name]
    cam = bpy.data.cameras.new("Camera")
    cam.lens = lens
    cam.sensor_width = 36
    ob = link(bpy.data.objects.new("Camera", cam))
    ob.location = loc
    target = Vector(target)
    ob.rotation_euler = (target - ob.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    cam.dof.use_dof = True
    cam.dof.focus_distance = (target - ob.location).length
    cam.dof.aperture_fstop = 5.6
    return ob


def render_settings(a):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:
        print("GPU setup failed, using CPU:", e)
    sc.cycles.samples = a.samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    sc.cycles.caustics_reflective = sc.cycles.caustics_refractive = False
    sc.cycles.blur_glossy = 1.0
    sc.render.resolution_x = a.width
    sc.render.resolution_y = a.height or round(a.width * 9 / 16)
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    for look in ("AgX - Medium High Contrast", "Medium High Contrast"):
        try:
            sc.view_settings.look = look
            break
        except TypeError:
            pass
    sc.view_settings.exposure = 0.8
    sc.render.image_settings.file_format = "PNG"


def materials():
    return {
        "floor": pbr("Floor", "wood_floor", scale=0.45, rough_mult=0.8, bump=0.15),
        "wall": pbr("Wall", "plastered_wall_04", scale=0.6, tint=(0.82, 0.76, 0.66), bump=0.08),
        "ceiling": flat("Ceiling", (0.85, 0.83, 0.79), 0.9),
        "ground": flat("Ground", (0.08, 0.12, 0.05), 0.95),
        "hall": flat("Hall", (0.8, 0.72, 0.6), 0.9),
        "trim": flat("Trim", (0.86, 0.84, 0.8), 0.35),
        "door": flat("Door", (0.84, 0.82, 0.77), 0.32),
        "blind": flat("Blind", (0.8, 0.78, 0.74), 0.85),
        "brass": flat("Brass", (0.85, 0.62, 0.3), 0.28, metal=1.0),
        "velvet": pbr("Velvet", "velour_velvet", scale=1.5, tint=(0.09, 0.14, 0.32), bump=0.1, sheen=0.6),
        "headboard": pbr("Headboard", "velour_velvet", scale=2.0, tint=(0.95, 0.68, 0.2), bump=0.1, sheen=0.4),
        "duvet": pbr("Duvet", "waffle_pique_cotton", scale=2.5, tint=(1.0, 0.97, 0.9), bump=0.2),
        "sheet": flat("Sheet", (0.9, 0.88, 0.84), 0.8),
        "pillow": pbr("Pillow", "waffle_pique_cotton", scale=3.0, tint=(0.98, 0.95, 0.88), bump=0.1),
        "throw": pbr("Throw", "knitted_fleece", scale=2.0, tint=(0.08, 0.16, 0.34), bump=0.3),
        "bedframe": pbr("BedFrame", "wood_floor", scale=1.5, tint=(0.42, 0.24, 0.13), rough_mult=0.7, bump=0.1),
        "walnut": flat("Walnut", (0.2, 0.11, 0.06), 0.4, coat=0.2),
        "ceramic": flat("Ceramic", (0.04, 0.09, 0.2), 0.15, coat=0.6),
        "shade": linen_shade("Shade"),
        "bulb": emissive("Bulb", (1.0, 0.78, 0.5), 0.0),
        "phone": flat("PhoneBody", (0.02, 0.02, 0.025), 0.15, coat=1.0),
        "screen": emissive("PhoneScreen", (0.55, 0.62, 1.0), 0.0),
        "bookA": flat("BookA", (0.75, 0.2, 0.15), 0.6),
        "rug": pbr("Rug", "knitted_fleece", scale=3.0, tint=(0.72, 0.5, 0.3), bump=0.8),
        "rugBorder": pbr("RugBorder", "knitted_fleece", scale=3.0, tint=(0.12, 0.17, 0.32), bump=0.8),
        "mat": flat("ArtMat", (0.93, 0.9, 0.84), 0.8),
        "print": image_mat("Print", os.path.join(HERE, "..", "NiteLite", "Assets.xcassets", "AppIcon.appiconset", "icon_512x512@2x.png")),
    }


def build(a):
    """Build the whole scene (both states present) and return handles for animating it."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    render_settings(a)
    M = materials()
    build_room(M)
    blinds = build_window(M)
    curtains = build_curtains(M)
    hinge, hall = build_door(M)
    build_bed(M)
    lamp, lamp_light = build_lamp(M)
    build_props(M)
    refs = dict(M=M, lamp_light=lamp_light, hall=hall, door=hinge, blinds=blinds, curtains=curtains)
    refs.update(world())
    refs.update(lights())
    refs["camera"] = camera(a.cam)
    return refs


def render_still(a, refs):
    apply_state(a.state, refs)
    if a.save:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "room.blend"))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    bpy.context.scene.render.filepath = os.path.abspath(a.out)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    a = args()
    render_still(a, build(a))
