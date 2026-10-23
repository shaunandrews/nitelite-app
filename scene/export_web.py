"""Export the bedroom for the realtime site: site/room/room.glb plus web textures.

    $BLENDER -b --factory-startup --disable-autoexec -P scene/export_web.py

Procedural meshes get their modifiers applied and world-scale box UVs (1 UV
unit = 1 metre), and plain placeholder materials named after their role
("Wall", "Velvet", ...). The site swaps those for textured three.js materials,
so look in site/js/room.js for colours and texture scales. Poly Haven props
keep their own materials, with images shrunk for the web. The curtains keep
their "Closed" shape key as a morph target. Lights aren't exported; the site
sets up its own.
"""
import math
import os
import shutil
import subprocess
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_scene as bs  # noqa: E402

OUT = os.path.abspath(os.path.join(bs.HERE, "..", "site", "room"))
# Poly Haven texture sets the site needs, and the web size for each
WEB_TEXTURES = {
    "wood_floor": 1024,
    "plastered_wall_04": 512,
    "velour_velvet": 512,
    "waffle_pique_cotton": 512,
    "rough_linen": 512,
    "knitted_fleece": 512,
}
DROP = ("Ground", "island_tree_02", "shrub_01", "shrub_04")


class A:
    state, cam, samples, width, height, save, out = "day", "wide", 1, 320, 0, False, ""


def root_of(o):
    while o.parent:
        o = o.parent
    return o


def box_uv(ob):
    """UVs from world position, projected along each face's dominant axis (metres)."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    mw = ob.matrix_world
    rot = mw.to_3x3()
    for poly in me.polygons:
        n = rot @ poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = ((1, 2), (0, 2), (0, 1))[ax]
        for li in poly.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co[a], co[b])


def apply_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)


def placeholder(mat):
    """Swap a node-heavy material for a flat one with the same name (the site retextures it)."""
    name = mat.name
    color = (0.8, 0.8, 0.8, 1)
    rough = 0.6
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.use_nodes else None
    if bsdf:
        if not bsdf.inputs["Base Color"].is_linked:
            color = tuple(bsdf.inputs["Base Color"].default_value)
        if not bsdf.inputs["Roughness"].is_linked:
            rough = bsdf.inputs["Roughness"].default_value
    mat.name = name + "_src"
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    return m


def main():
    refs = bs.build(A)
    bs.apply_state("day", refs)
    bpy.context.view_layer.update()

    # Outdoors is the sky in the browser; trees and lawn are too heavy for the web
    for o in list(bpy.data.objects):
        if o.name.startswith(DROP) or root_of(o).name.startswith(DROP):
            bpy.data.objects.remove(o, do_unlink=True)

    imported = {o for o in bpy.data.objects if root_of(o).name.endswith("_root")}
    swapped = {}
    for ob in [o for o in bpy.data.objects if o.type == "MESH" and o not in imported]:
        if ob.data.shape_keys:  # curtains: keep the morph, drop the thickness
            ob.modifiers.clear()
        else:
            if ob.name in ("Duvet", "Throw"):  # the sim mesh is dense enough; thickness is a double-sided material
                for m in [m for m in ob.modifiers if m.type in ("SUBSURF", "SOLIDIFY")]:
                    ob.modifiers.remove(m)
            apply_modifiers(ob)
        if ob.name != "ArtPrint":  # the print has real UVs for its image
            box_uv(ob)
        for slot in ob.material_slots:
            if slot.material and slot.material.name not in ("Print",):
                src = slot.material
                if src.name not in swapped:
                    swapped[src.name] = placeholder(src)
                slot.material = swapped[src.name]

    # Shrink the props' textures for the web: big pieces get 1k, small ones 512
    for img in bpy.data.images:
        if img.source != "FILE" or img.size[0] == 0:
            continue
        cap = 1024 if img.name.startswith(("painted_wooden_nightstand", "Television_01")) else 512
        if img.size[0] > cap:
            img.scale(cap, cap * img.size[1] // img.size[0])

    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, "room.glb"),
        export_format="GLB",
        use_selection=False,
        export_apply=False,
        export_morph=True,
        export_morph_normal=False,
        export_lights=False,
        export_cameras=False,
        export_image_format="JPEG",
        export_jpeg_quality=80,
        export_draco_mesh_compression_enable=True,
        export_draco_mesh_compression_level=6,
    )

    # Tileable textures for the site's own materials
    tex_out = os.path.join(OUT, "tex")
    os.makedirs(tex_out, exist_ok=True)
    for name, size in WEB_TEXTURES.items():
        for kind in ("Diffuse", "Rough"):
            src = os.path.join(bs.ASSETS, "textures", name, f"{kind}.jpg")
            if os.path.exists(src):
                dst = os.path.join(tex_out, f"{name}_{kind.lower()}.jpg")
                subprocess.run(["sips", "-Z", str(size), "-s", "formatOptions", "75", src, "--out", dst], check=True, capture_output=True)

    # Skies, shrunk to 1k equirect HDRs
    for name in ("kloofendal_48d_partly_cloudy_puresky", "qwantani_moonrise_puresky"):
        img = bpy.data.images.load(os.path.join(bs.ASSETS, "hdri", f"{name}.hdr"))
        img.scale(1024, 512)
        img.filepath_raw = os.path.join(OUT, f"{name}_1k.hdr")
        img.file_format = "HDR"
        img.save()
    print("EXPORTED", os.path.getsize(os.path.join(OUT, "room.glb")) // 1024, "KB")


main()
