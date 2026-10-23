#!/usr/bin/env python3 -I
"""Download the CC0 Poly Haven assets the bedroom scene uses into scene/assets/.

    python3 -I scene/fetch_assets.py

Models come down as glTF (plain data, no embedded scripts). Files are checked
against Poly Haven's md5 and skipped when already present, so re-running is cheap.
All assets are CC0: https://polyhaven.com/license
"""
import hashlib
import json
import os
import sys
import urllib.request

API = "https://api.polyhaven.com/files/"
UA = {"User-Agent": "NiteLite-scene/1.0"}
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")

# model id -> resolution (big outdoor models at 1k; they're only seen through the window)
MODELS = {
    "painted_wooden_nightstand": "2k",
    "alarm_clock_01": "2k",
    "Television_01": "2k",
    "filmstrip_projector_8mm": "2k",
    "potted_plant_02": "2k",
    "standing_picture_frame_01": "2k",
    "island_tree_02": "1k",
    "shrub_01": "1k",
    "shrub_04": "1k",
}
# texture id -> maps to fetch
TEXTURES = {
    "wood_floor": ["Diffuse", "nor_gl", "Rough"],
    "plastered_wall_04": ["nor_gl", "Rough"],
    "velour_velvet": ["Diffuse", "nor_gl", "Rough"],
    "waffle_pique_cotton": ["Diffuse", "nor_gl", "Rough"],
    "rough_linen": ["Diffuse", "nor_gl", "Rough"],
    "knitted_fleece": ["Diffuse", "nor_gl", "Rough"],
}
HDRIS = ["qwantani_moonrise_puresky", "kloofendal_48d_partly_cloudy_puresky"]
RES = "2k"


def get_json(asset):
    with urllib.request.urlopen(urllib.request.Request(API + asset, headers=UA)) as r:
        return json.load(r)


def fetch(url, dest, md5=None):
    if os.path.exists(dest) and (md5 is None or hashlib.md5(open(dest, "rb").read()).hexdigest() == md5):
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
        data = r.read()
    if md5 and hashlib.md5(data).hexdigest() != md5:
        sys.exit(f"md5 mismatch for {url}")
    with open(dest, "wb") as f:
        f.write(data)
    print("  ", os.path.relpath(dest, ROOT))


def main():
    for m, res in MODELS.items():
        print("model", m)
        g = get_json(m)["gltf"][res]["gltf"]
        base = os.path.join(ROOT, "models", m)
        fetch(g["url"], os.path.join(base, f"{m}.gltf"), g["md5"])
        for rel, info in g["include"].items():
            fetch(info["url"], os.path.join(base, rel), info["md5"])

    for t, maps in TEXTURES.items():
        print("texture", t)
        files = get_json(t)
        for kind in maps:
            info = files[kind][RES]["jpg"]
            fetch(info["url"], os.path.join(ROOT, "textures", t, f"{kind}.jpg"), info["md5"])

    for h in HDRIS:
        print("hdri", h)
        info = get_json(h)["hdri"][RES]["hdr"]
        fetch(info["url"], os.path.join(ROOT, "hdri", f"{h}.hdr"), info["md5"])


if __name__ == "__main__":
    main()
