#!/usr/bin/env bash
# dreamina-delogo — remove the top-left "AI" badge from Dreamina-generated MP4s.
#
# Single file:   delogo.sh video.mp4 [output.mp4]
# Directory:     delogo.sh /path/to/folder        # processes *.mp4 / *.mov
#
# Tunable defaults are calibrated for Dreamina vertical 834x1112.
# Override via env vars: LOGO_X LOGO_Y LOGO_W LOGO_H BLUR_W BLUR_H BLUR_CX BLUR_CY BLUR_R0 BLUR_R1 BLUR_SIGMA CRF PRESET

set -euo pipefail

LOGO_X=${LOGO_X:-10}
LOGO_Y=${LOGO_Y:-10}
LOGO_W=${LOGO_W:-66}
LOGO_H=${LOGO_H:-52}
BLUR_W=${BLUR_W:-84}
BLUR_H=${BLUR_H:-74}
BLUR_CX=${BLUR_CX:-40}
BLUR_CY=${BLUR_CY:-34}
BLUR_R0=${BLUR_R0:-28}
BLUR_R1=${BLUR_R1:-40}
BLUR_SIGMA=${BLUR_SIGMA:-2}
CRF=${CRF:-18}
PRESET=${PRESET:-medium}

usage() {
  cat <<EOF
Usage: $(basename "$0") <input.mp4|directory> [output.mp4]

Single file:
  $(basename "$0") video.mp4              # writes video-clean.mp4
  $(basename "$0") video.mp4 result.mp4   # custom output

Directory (batch):
  $(basename "$0") /path/to/folder        # processes every *.mp4 / *.mov

Tunable env vars (defaults for Dreamina 834x1112 top-left "AI" badge):
  LOGO_X LOGO_Y LOGO_W LOGO_H        delogo bounding box
  BLUR_W BLUR_H                      feather zone (anchored at 0,0)
  BLUR_CX BLUR_CY                    blur center inside cropped zone
  BLUR_R0 BLUR_R1                    inner/outer radius for radial fade
  BLUR_SIGMA                         gaussian sigma
  CRF PRESET                         x264 quality knobs (default 18 medium)
EOF
}

if [[ $# -lt 1 ]]; then usage; exit 1; fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found in PATH. Install: https://ffmpeg.org/" >&2
  exit 2
fi

fr=$(( BLUR_R1 - BLUR_R0 ))
filter="[0:v]delogo=x=${LOGO_X}:y=${LOGO_Y}:w=${LOGO_W}:h=${LOGO_H}[clean];[clean]split=2[base][src];[src]crop=${BLUR_W}:${BLUR_H}:0:0,gblur=sigma=${BLUR_SIGMA}[blur];color=c=black:s=${BLUR_W}x${BLUR_H}:r=60:d=20,format=gray,geq=lum=255*max(0\\,min(1\\,(${BLUR_R1}-hypot(X-${BLUR_CX}\\,Y-${BLUR_CY}))/${fr}))[mask];[blur][mask]alphamerge[blur_a];[base][blur_a]overlay=0:0:format=auto:shortest=1[out]"

run_one() {
  local in="$1" out="$2"
  echo ">> $(basename "$in") -> $(basename "$out")"
  ffmpeg -y -loglevel error -stats \
    -i "$in" \
    -filter_complex "$filter" \
    -map '[out]' -map '0:a?' \
    -c:v libx264 -crf "$CRF" -preset "$PRESET" \
    -c:a copy \
    "$out"
}

target="$1"

if [[ -d "$target" ]]; then
  shopt -s nullglob nocaseglob
  count=0
  for f in "$target"/*.mp4 "$target"/*.mov; do
    [[ -f "$f" ]] || continue
    case "$f" in *-clean.mp4|*-clean.mov) continue ;; esac
    base="${f%.*}"; ext="${f##*.}"
    run_one "$f" "${base}-clean.${ext}"
    count=$((count+1))
  done
  echo "Done. Processed $count file(s)."
elif [[ -f "$target" ]]; then
  if [[ $# -ge 2 ]]; then
    out="$2"
  else
    base="${target%.*}"; ext="${target##*.}"
    out="${base}-clean.${ext}"
  fi
  run_one "$target" "$out"
else
  echo "ERROR: '$target' is not a file or directory." >&2
  exit 1
fi
