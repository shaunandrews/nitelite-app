#!/bin/bash
# Render every transition clip at full quality, then encode them for the site.
#
#   scene/render_clips.sh                 # all clips
#   scene/render_clips.sh tv projector    # just these
#
# ~7s per frame at 1600x900 / 48 samples on an M4 Pro: about 30 minutes for all five.
set -euo pipefail
cd "$(dirname "$0")/.."

BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
if [[ $# -gt 0 ]]; then CLIPS=("$@"); else CLIPS=(curtains blinds tv projector door); fi

for clip in "${CLIPS[@]}"; do
    echo "== $clip"
    rm -rf "scene/renders/clips/$clip"
    "$BLENDER" -b --factory-startup --disable-autoexec -P scene/animate.py -- \
        --clip "$clip" --samples 48 --width 1600 2>&1 | grep --line-buffered -E "Saved:|Error|Traceback" || true
done

scene/encode.sh
