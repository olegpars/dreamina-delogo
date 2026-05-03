---
name: dreamina-delogo
description: Use when removing the top-left "AI" badge watermark from Dreamina-generated MP4 / MOV videos, single file or whole folder. Triggers — user mentions "Dreamina watermark", "AI badge", "delogo", "убрать вотермарк с видео", "стереть AI", or shows a vertical 9:12 clip with a fixed corner watermark. Skip if watermark is animated, large, or sits over fine detail (use AI inpainting instead).
---

# dreamina-delogo

Remove a fixed-position corner watermark from a video using FFmpeg only — no AI, no upload, runs locally.

## When to use

- Fixed-position badge in a corner of an MP4/MOV (Dreamina default: top-left "AI" at 834×1112).
- Background under the badge is uniform (sky, gradient, soft texture) OR footage has motion/grain that hides soft patches.
- User wants offline, fast turnaround, no GPU required.

## When NOT to use

- Watermark moves or animates → AI inpainting (ProPainter, RunwayML Erase & Replace, Topaz Video AI).
- Badge sits over a face / fine text / intricate texture and result will be inspected at 4K → AI inpainting.
- Large area (>10% of frame) → AI inpainting.

## Quick reference

```bash
# single file → writes <name>-clean.<ext> next to input
bash delogo.sh /path/to/video.mp4

# whole folder → processes every *.mp4 / *.mov, skips *-clean.*
bash delogo.sh /path/to/folder
```

PowerShell: `./delogo.ps1 <file-or-folder>`. Same parameters.

## Tunable parameters

Defaults are calibrated for Dreamina vertical 834×1112 top-left badge. Override via env vars (bash) or `-Param` (PowerShell):

| Var | Default | Meaning |
|---|---|---|
| `LOGO_X` `LOGO_Y` | 10 10 | delogo bounding box top-left |
| `LOGO_W` `LOGO_H` | 66 52 | delogo box size |
| `BLUR_W` `BLUR_H` | 84 74 | feather zone (anchored at 0,0) |
| `BLUR_CX` `BLUR_CY` | 40 34 | blur center inside cropped zone |
| `BLUR_R0` `BLUR_R1` | 28 40 | inner / outer radius for radial fade |
| `BLUR_SIGMA` | 2 | gaussian sigma |
| `CRF` `PRESET` | 18 medium | x264 quality |

## Finding coordinates for a non-default watermark

```bash
ffmpeg -ss 1 -i input.mp4 -frames:v 1 frame.png
```

Open `frame.png` in any viewer that shows pixel coordinates. Read off the watermark bounding box. Plug values into the variables above. Set `BLUR_CX`/`BLUR_CY` to the badge center, `BLUR_R1` slightly larger than half the longest side, `BLUR_R0` ≈ `BLUR_R1 - 12`.

## How it works

Two filters stacked in `filter_complex`:

1. **`delogo`** — replaces every pixel inside the bounding box with an interpolated value sampled from the box's edge.
2. **Radial-feathered overlay** — crops the same corner, applies a slight `gblur`, generates an alpha mask via `geq` (full opaque at center → transparent at outer radius), and overlays through that mask. This hides the rectangular seam between interpolated and original pixels.

## Verify

- Output `.mp4` exists; `ffprobe` shows same width × height × fps × duration as input.
- Visual inspection: watermark gone, no rectangular seam visible.
- Audio preserved (`-c:a copy`, lossless passthrough).

## Common mistakes

- **Watermark still partially visible** → expand `LOGO_W` / `LOGO_H` by 5–10 px.
- **Soft "patch" visible on detailed background** → expected on fine texture; raise `BLUR_SIGMA` for softer blend, OR accept it (movement hides it). For perfect results on detail use AI inpainting.
- **Coordinates off** → re-extract a frame, re-measure. Don't guess.
- **Output file locked** → close it in any video player before re-running.
