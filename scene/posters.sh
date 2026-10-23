#!/bin/bash
# Render the two stills the site shows while the 3D room loads (and without WebGL).
#   scene/posters.sh     # ~1 min on an M4 Pro
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
mkdir -p site/room
for state in day night; do
    "$BLENDER" -b --factory-startup --disable-autoexec -P scene/build_scene.py -- \
        --state "$state" --cam wide --samples 96 --width 1600 --out "scene/renders/$state.png" >/dev/null
    sips -s format jpeg -s formatOptions 78 "scene/renders/$state.png" --out "site/room/$state.jpg" >/dev/null
done
ls -la site/room/day.jpg site/room/night.jpg
