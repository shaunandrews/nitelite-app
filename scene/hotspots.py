"""Write site/room/hotspots.json: where each clickable object sits in the wide shot,
as fractions of the frame (x from the left, y from the top).

    $BLENDER -b --factory-startup --disable-autoexec -P scene/hotspots.py
"""
import json
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_scene as bs  # noqa: E402


class A:
    state, cam, samples, width, height, save, out = "day", "wide", 1, 320, 0, False, ""


def center(names):
    """Bounding-box centre of the named objects (and their children)."""
    pts = []
    for n in names:
        ob = bpy.data.objects[n]
        for o in [ob] + list(ob.children_recursive):
            if o.type == "MESH":
                pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return (lo + hi) / 2


refs = bs.build(A)
bs.apply_state("day", refs)
bpy.context.view_layer.update()
sc, cam = bpy.context.scene, refs["camera"]
points = {
    "lamp": center(["LampShade"]),
    "chain": bpy.data.objects["ChainPull"].matrix_world.translation,
    "clock": center(["alarm_clock_01_root"]),
    "phone": center(["Phone"]),
    "tv": center(["Television_01_root"]),
    "projector": center(["filmstrip_projector_8mm_root"]),
    "door": Vector(((bs.DOOR["x0"] + bs.DOOR["x1"]) / 2, bs.ROOM["y1"], 1.1)),
    "blinds": Vector((bs.ROOM["x1"], (bs.WINDOW["y0"] + bs.WINDOW["y1"]) / 2, (bs.WINDOW["z0"] + bs.WINDOW["z1"]) / 2)),
    "curtains": center(["CurtainR"]),
    "art": center(["ArtFrame"]),
    "wall": Vector((-1.0, bs.ROOM["y1"], 1.95)),
}
out = {}
for name, p in points.items():
    v = world_to_camera_view(sc, cam, p)
    out[name] = {"x": round(v.x, 4), "y": round(1 - v.y, 4)}
path = os.path.join(bs.HERE, "..", "site", "room", "hotspots.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(out, f, indent=1)
print("HOTSPOTS", json.dumps(out))
