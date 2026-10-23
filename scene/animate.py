"""Render the website's transition clips: each one goes day → black → night.

    BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
    $BLENDER -b --factory-startup --disable-autoexec -P scene/animate.py -- \
        --clip curtains [--samples 64] [--width 1600] [--frames 1-40]

Frames land in scene/renders/clips/<clip>/####.png. Every clip is symmetric
(close → black → swap → open), so the night → day version is the same frames
played backwards; scene/encode.sh makes both videos.

Timeline (24 fps, 48 frames): the object acts in full light over frames 1–18,
the picture dips to black only at the end of that (15–20), day/night swap on
frame 24 while black, the picture comes back over 26–31 and the object
reopens by 46.
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_scene as bs  # noqa: E402

FPS = 24
LAST = 48
SWAP = 24
DOWN, BLACK_AT, UP, UP_DONE = 15, 20, 26, 31  # default exposure dip
BLACK = -10.0  # exposure that reads as black
CLIPS = ("curtains", "blinds", "tv", "projector", "door")


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--clip", choices=CLIPS, required=True)
    p.add_argument("--samples", type=int, default=64)
    p.add_argument("--width", type=int, default=1600)
    p.add_argument("--frames", default=f"1-{LAST}", help="range like 1-40, or a list like 1,10,20")
    a = p.parse_args(argv)
    a.state, a.cam, a.height, a.save, a.out = "day", "wide", 0, False, ""
    return a


def k(owner, path, frame, value, interp="BEZIER"):
    """Set owner.path = value and keyframe it at frame."""
    if isinstance(path, str) and "[" not in path:
        setattr(owner, path, value)
    bs.key(owner, path, frame, interp)


# ---------------------------------------------------------------- shared beats

def exposure_dip(down_from=DOWN, black_at=BLACK_AT, up_from=UP, up_to=UP_DONE):
    vs = bpy.context.scene.view_settings
    base = vs.exposure
    k(vs, "exposure", down_from, base)
    k(vs, "exposure", black_at, BLACK)
    k(vs, "exposure", up_from, BLACK)
    k(vs, "exposure", up_to, base)


def camera_move(cam, shots):
    """shots: [(frame, location, target, lens)] keyed with eased Bezier moves."""
    for frame, loc, target, lens in shots:
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        cam.data.dof.focus_distance = (Vector(target) - Vector(loc)).length
        for path in ("location", "rotation_euler"):
            bs.key(cam, path, frame, "BEZIER")
        bs.key(cam.data, "lens", frame, "BEZIER")
        bs.key(cam.data.dof, "focus_distance", frame, "BEZIER")


def wide_shot():
    loc, target, lens = bs.CAMERAS["wide"]
    return loc, target, lens


def uv_plane(name, w, h, mat):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((x * w / 2, 0, z * h / 2)) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    face = bm.faces.new(vs)
    for loop, (u, v) in zip(face.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv].uv = (u, v)
    return bs.mesh_obj(name, bm, mat)


def value_node(nt, name, default=0.0):
    n = nt.nodes.new("ShaderNodeValue")
    n.name = name
    n.outputs[0].default_value = default
    return n.outputs[0]


def math_node(nt, op, a, b=None):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def emission_only(name):
    """Emission that fades to fully transparent where its strength is 0, so the
    plane is invisible when the TV/projector is off."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    em = nt.nodes.new("ShaderNodeEmission")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.name = "Visible"
    nt.links.new(nt.nodes.new("ShaderNodeBsdfTransparent").outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    uvs = nt.nodes.new("ShaderNodeSeparateXYZ")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.name = "Texture Coordinate"
    nt.links.new(tc.outputs["UV"], uvs.inputs[0])
    return m, nt, em, uvs.outputs["X"], uvs.outputs["Y"]


# ---------------------------------------------------------------- clips

def clip_curtains(refs, cam):
    for f, closed in ((1, 0.0), (17, 1.0), (SWAP, 1.0), (27, 1.0), (46, 0.0)):
        bs.set_curtains(refs["curtains"], closed, f)
    exposure_dip()
    loc, target, lens = wide_shot()
    nudge = (loc[0] + 0.25, loc[1] + 0.35, loc[2]), (target[0] + 0.5, target[1], target[2]), lens
    camera_move(cam, [(1, loc, target, lens), (BLACK_AT, *nudge), (UP, *nudge), (LAST, loc, target, lens)])


def clip_blinds(refs, cam):
    day, night = bs.STATES["day"]["blinds"], bs.STATES["night"]["blinds"]
    for f, tilt in ((1, day), (6, day), (17, 88), (SWAP, 88), (28, 88), (44, night)):
        bs.set_blinds(refs["blinds"], tilt, f)
    exposure_dip()
    loc, target, lens = wide_shot()
    win = (1.1, -0.9, 1.4), (2.6, 0.9, 1.45), 30
    camera_move(cam, [(1, loc, target, lens), (12, *win), (UP + 2, *win), (LAST, loc, target, lens)])


def clip_tv(refs, cam):
    tv = bpy.data.objects["Television_01_root"]
    m, nt, em, u, v = emission_only("TVScreen")
    sx, sy = value_node(nt, "sx", 1.0), value_node(nt, "sy", 1.0)
    power, dot = value_node(nt, "power"), value_node(nt, "dot")
    # Rectangle that collapses to a line, then a dot (like the app's Old TV transition)
    in_x = math_node(nt, "LESS_THAN", math_node(nt, "MULTIPLY", math_node(nt, "ABSOLUTE", math_node(nt, "SUBTRACT", u, 0.5)), 2.0), sx)
    in_y = math_node(nt, "LESS_THAN", math_node(nt, "MULTIPLY", math_node(nt, "ABSOLUTE", math_node(nt, "SUBTRACT", v, 0.5)), 2.0), sy)
    rect = math_node(nt, "MULTIPLY", math_node(nt, "MULTIPLY", in_x, in_y), power)
    dx = math_node(nt, "SUBTRACT", u, 0.5)
    dy = math_node(nt, "MULTIPLY", math_node(nt, "SUBTRACT", v, 0.5), 0.75)
    dist = math_node(nt, "SQRT", math_node(nt, "ADD", math_node(nt, "MULTIPLY", dx, dx), math_node(nt, "MULTIPLY", dy, dy)))
    glow = math_node(nt, "MULTIPLY", math_node(nt, "MAXIMUM", math_node(nt, "SUBTRACT", 1.0, math_node(nt, "DIVIDE", dist, 0.06)), 0.0), dot)
    # Bluish static and scanlines. Static is chunky (snapped UVs) because the
    # denoiser wipes out per-pixel noise.
    snap = nt.nodes.new("ShaderNodeVectorMath")
    snap.operation = "SNAP"
    snap.inputs[1].default_value = (1 / 120, 1 / 90, 1)
    nt.links.new(nt.nodes["Texture Coordinate"].outputs["UV"], snap.inputs[0])
    noise = nt.nodes.new("ShaderNodeTexWhiteNoise")
    noise.noise_dimensions = "4D"
    nt.links.new(snap.outputs["Vector"], noise.inputs["Vector"])
    noise.inputs["W"].driver_add("default_value").driver.expression = "frame"
    static = math_node(nt, "ADD", 0.7, math_node(nt, "MULTIPLY", noise.outputs["Value"], 0.3))
    lines = math_node(nt, "ADD", 0.82, math_node(nt, "MULTIPLY", math_node(nt, "SINE", math_node(nt, "MULTIPLY", v, 560.0)), 0.18))
    tintc = nt.nodes.new("ShaderNodeMix")
    tintc.data_type, tintc.blend_type = "RGBA", "MULTIPLY"
    tintc.inputs["Factor"].default_value = 1.0
    tintc.inputs["B"].default_value = (0.62, 0.78, 1.0, 1)
    nt.links.new(math_node(nt, "MULTIPLY", static, lines), tintc.inputs["A"])
    nt.links.new(tintc.outputs["Result"], em.inputs["Color"])
    light = math_node(nt, "ADD", math_node(nt, "MULTIPLY", rect, 1.1), math_node(nt, "MULTIPLY", glow, 30.0))
    nt.links.new(light, em.inputs["Strength"])
    nt.links.new(math_node(nt, "MINIMUM", light, 1.0), nt.nodes["Visible"].inputs["Fac"])
    screen = uv_plane("TVGlow", 0.37, 0.285, m)
    screen.parent = tv
    screen.location = (-0.072, -0.218, 0.262)

    def node(name):
        return nt.nodes[name].outputs[0]
    keys = {
        # TV flicks on while the camera rushes in
        "power": [(1, 0.0), (5, 1.0), (36, 1.0), (43, 0.0)],
        # CRT switch-off: squeeze to a line, then to a dot, which fades
        "sy": [(13, 1.0), (15, 0.012), (29, 0.012), (31, 1.0)],
        "sx": [(15, 1.0), (17, 0.0), (27, 0.0), (29, 1.0)],
        "dot": [(15, 0.0), (17, 1.0), (19, 0.0), (26, 0.0), (27, 0.9), (29, 0.0)],
    }
    for name, pts in keys.items():
        for f, val in pts:
            k(node(name), "default_value", f, val)
    exposure_dip(16, 19, 27, 30)
    loc, target, lens = wide_shot()
    bpy.context.view_layer.update()  # so the parented screen's matrix_world is real
    screen_c = screen.matrix_world @ Vector((0, 0, 0))
    close = (screen_c.x - 0.04, screen_c.y - 0.42, screen_c.z + 0.02), tuple(screen_c), 30
    # Swing left of the bed on the way in and out
    side = (-1.3, -1.0, 1.15), (screen_c.x, screen_c.y, screen_c.z), 26
    camera_move(cam, [(1, loc, target, lens), (6, *side), (12, *close), (32, *close), (40, *side), (LAST, loc, target, lens)])


def clip_projector(refs, cam):
    # The floor projector (placed in build_scene) throws a picture onto the wall above the TV
    m, nt, em, u, v = emission_only("Projection")
    power, iris = value_node(nt, "power"), value_node(nt, "iris", 1.0)
    dx = math_node(nt, "SUBTRACT", u, 0.5)
    dy = math_node(nt, "MULTIPLY", math_node(nt, "SUBTRACT", v, 0.5), 0.58)
    dist = math_node(nt, "SQRT", math_node(nt, "ADD", math_node(nt, "MULTIPLY", dx, dx), math_node(nt, "MULTIPLY", dy, dy)))
    # Iris: soft-edged circle whose radius (0..0.6 covers the whole frame) is keyed
    inside = math_node(nt, "GREATER_THAN", math_node(nt, "MULTIPLY", iris, 0.6), dist)
    vign = math_node(nt, "SUBTRACT", 1.0, math_node(nt, "MULTIPLY", dist, 0.9))
    em.inputs["Color"].default_value = (1.0, 0.93, 0.78, 1)
    light = math_node(nt, "MULTIPLY", math_node(nt, "MULTIPLY", math_node(nt, "MULTIPLY", inside, vign), power), 5.0)
    nt.links.new(light, em.inputs["Strength"])
    nt.links.new(math_node(nt, "MINIMUM", light, 1.0), nt.nodes["Visible"].inputs["Fac"])
    wall_y = bs.ROOM["y1"] - 0.003
    pic = uv_plane("Projection", 1.2, 0.69, m)
    pic.location = (-0.95, wall_y, 1.55)
    spot = bpy.data.lights.new("ProjectorBeam", "SPOT")
    spot.spot_size, spot.spot_blend, spot.color = math.radians(40), 0.6, (1.0, 0.9, 0.75)
    so = bs.link(bpy.data.objects.new("ProjectorBeam", spot))
    so.location = (-1.15, 0.2, 0.2)
    so.rotation_euler = (Vector((-0.95, wall_y, 1.55)) - so.location).to_track_quat("-Z", "Y").to_euler()

    def node(name):
        return nt.nodes[name].outputs[0]
    for f, val in ((1, 0.0), (4, 1.0), (38, 1.0), (44, 0.0)):
        k(node("power"), "default_value", f, val)
        k(spot, "energy", f, 60.0 * val)
    for f, val in ((9, 1.0), (19, 0.0), (28, 0.0), (37, 1.0)):
        k(node("iris"), "default_value", f, val)
    exposure_dip(14, 20, 26, 32)
    loc, target, lens = wide_shot()
    close = (-0.95, 0.55, 1.5), (-0.95, wall_y, 1.55), 28
    camera_move(cam, [(1, loc, target, lens), (12, *close), (34, *close), (LAST, loc, target, lens)])


def clip_door(refs, cam):
    hinge = refs["door"]
    for f, deg in ((1, -18), (8, -18), (18, 0), (SWAP, 0), (28, 0), (40, -18)):
        k(hinge, "rotation_euler", f, (0, 0, math.radians(deg)))
    exposure_dip(16, 20, 27, 32)
    loc, target, lens = wide_shot()
    d = bs.DOOR
    door_c = ((d["x0"] + d["x1"]) / 2, bs.ROOM["y1"], 1.05)
    close = (door_c[0] + 0.25, door_c[1] - 1.7, 1.2), door_c, 30
    camera_move(cam, [(1, loc, target, lens), (12, *close), (34, *close), (LAST, loc, target, lens)])


def frames(spec):
    if "-" in spec:
        a, b = spec.split("-")
        return list(range(int(a), int(b) + 1))
    return [int(x) for x in spec.split(",")]


def main():
    a = args()
    refs = bs.build(a)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, LAST
    cam = refs["camera"]
    # Day at the start, night from the swap frame on
    bs.apply_state("day", refs, frame=1)
    bs.apply_state("night", refs, frame=SWAP)
    globals()[f"clip_{a.clip}"](refs, cam)
    out = os.path.join(bs.HERE, "renders", "clips", a.clip)
    os.makedirs(out, exist_ok=True)
    for f in frames(a.frames):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(out, f"{f:04d}.png")
        bpy.ops.render.render(write_still=True)


main()
