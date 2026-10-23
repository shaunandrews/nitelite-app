#!/bin/bash
# Encode rendered clip frames into the site's videos and stills.
#
# Each clip is rendered day → night. The night → day version is the same
# frames reversed, which works because every clip is symmetric
# (close → black → swap → open).
#
# Output (site/room/):
#   <clip>-night.mp4 / .webm   day → night
#   <clip>-day.mp4 / .webm     night → day
#   day.jpg, night.jpg         resting stills (frame 1 and the last frame)
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=scene/renders/clips
OUT=site/room
mkdir -p "$OUT"

for dir in "$SRC"/*/; do
    clip=$(basename "$dir")
    frames=$(ls "$dir"*.png | wc -l | tr -d ' ')
    if [[ "$frames" -lt 48 ]]; then
        echo "skip $clip ($frames frames)"
        continue
    fi
    echo "encode $clip"
    for dir_name in night day; do
        vf="scale=1600:-2"
        [[ $dir_name == day ]] && vf="reverse,$vf"
        ffmpeg -loglevel error -y -framerate 24 -i "$dir%04d.png" -vf "$vf" \
            -c:v libx264 -crf 22 -preset slow -pix_fmt yuv420p -movflags +faststart -an \
            "$OUT/$clip-$dir_name.mp4"
        ffmpeg -loglevel error -y -framerate 24 -i "$dir%04d.png" -vf "$vf" \
            -c:v libvpx-vp9 -crf 34 -b:v 0 -row-mt 1 -pix_fmt yuv420p -an \
            "$OUT/$clip-$dir_name.webm"
    done
done

# Resting stills: every clip starts on the same day frame and ends on the same night frame
first=$(ls -d "$SRC"/*/ | head -1)
ffmpeg -loglevel error -y -i "${first}0001.png" -vf scale=1600:-2 -q:v 3 "$OUT/day.jpg"
ffmpeg -loglevel error -y -i "$(ls "$first"*.png | tail -1)" -vf scale=1600:-2 -q:v 3 "$OUT/night.jpg"
ls -la "$OUT"
