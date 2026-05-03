# dreamina-delogo

Remove Dreamina's top-left **AI** badge watermark from generated videos. Pure FFmpeg, no AI, no cloud, no upload — runs locally on whatever machine you have.

Single file or batch the whole folder. Uses `delogo` (per-pixel interpolation) plus a radial-feathered gaussian blur on top so you don't see the rectangular seam — the patch fades smoothly into the surrounding image.

## Examples

Two before/after pairs from real Dreamina output, plus a side-by-side comparison clip. All are 480p re-encodes for size — the actual script keeps your source resolution.

| | Original | Clean |
|---|---|---|
| Static camera, soft sky background — easy case, watermark vanishes | [examples/01-original.mp4](examples/01-original.mp4) | [examples/01-clean.mp4](examples/01-clean.mp4) |
| Shaky handheld, busy detailed ground — harder case, motion hides any softness | [examples/02-original.mp4](examples/02-original.mp4) | [examples/02-clean.mp4](examples/02-clean.mp4) |

Side-by-side comparison (6s, labeled): [examples/comparison.mp4](examples/comparison.mp4)

> GitHub renders `.mp4` links inline on the file page — click any link above to play in browser.

## Why

Dreamina (and most AI video generators) stamps a small badge in the corner. If you're cutting a Reel/Short and want it to look clean — you need it gone. Online tools want you to upload your videos to their server. This script does it on your laptop in ~30 seconds per 15-second clip.

## Quick start

**1. Install FFmpeg** (if you don't have it):
- macOS: `brew install ffmpeg`
- Windows: <https://www.gyan.dev/ffmpeg/builds/> → download "full" build → add `bin/` to PATH
- Linux: `sudo apt install ffmpeg` / your distro's equivalent

Verify: `ffmpeg -version` should print a version banner.

**2. Clone or download** this repo:

```bash
git clone https://github.com/olegpars/dreamina-delogo.git
cd dreamina-delogo
```

**3. Run on a single file:**

```bash
# bash / git-bash / WSL / macOS / Linux
bash delogo.sh /path/to/video.mp4
# → writes /path/to/video-clean.mp4 next to it
```

```powershell
# Windows PowerShell
./delogo.ps1 C:\path\to\video.mp4
```

**Or batch a whole folder:**

```bash
bash delogo.sh /path/to/folder
# processes every *.mp4 / *.mov, skips ones already named *-clean.*
```

```powershell
./delogo.ps1 C:\path\to\folder
```

That's it. Audio is preserved bit-for-bit (`-c:a copy`). Video re-encoded at CRF 18 (visually-transparent quality).

## How it looks

- Watermark **gone**, no rectangular seam.
- On smooth backgrounds (sky, gradient, solid color) — invisible.
- On busy detailed backgrounds — slightly soft patch where the badge was, much less noticeable than the badge itself.

## Tunable parameters

Defaults are calibrated for **Dreamina vertical 834×1112** with the AI badge in the top-left. If your watermark sits elsewhere (different generator, horizontal video, etc.), override:

| Variable | Default | What it does |
|---|---|---|
| `LOGO_X`, `LOGO_Y` | 10, 10 | top-left corner of the delogo bounding box |
| `LOGO_W`, `LOGO_H` | 66, 52 | size of the delogo box (covers the badge with a few px margin) |
| `BLUR_W`, `BLUR_H` | 84, 74 | size of the feather zone (always anchored at 0,0 — change in source if you need a different anchor) |
| `BLUR_CX`, `BLUR_CY` | 40, 34 | center of the radial blur inside the cropped zone |
| `BLUR_R0`, `BLUR_R1` | 28, 40 | inner / outer radius of the blur fade (full → zero) |
| `BLUR_SIGMA` | 2 | gaussian strength (higher = softer, more diffuse) |
| `CRF` | 18 | x264 quality (16–20 is a good range) |
| `PRESET` | medium | x264 speed preset |

**bash:**
```bash
LOGO_X=20 LOGO_Y=20 LOGO_W=80 BLUR_SIGMA=3 bash delogo.sh video.mp4
```

**PowerShell:**
```powershell
./delogo.ps1 video.mp4 -LogoX 20 -LogoY 20 -LogoW 80 -BlurSigma 3
```

### Finding the right coordinates

```bash
# extract a single frame at second 1
ffmpeg -ss 1 -i video.mp4 -frames:v 1 frame.png
```

Open `frame.png` in any image viewer that shows pixel coordinates (Photoshop, IrfanView, Paint, GIMP, even browser DevTools after dragging it in). Hover over the watermark, read off the bounding box, plug into the variables above.

## How it works

Two filters stacked:

1. **`delogo`** — replaces every pixel inside the bounding box with an interpolated value sampled from the rectangle's edge. Fast, deterministic, works frame-by-frame.
2. **Radial-feathered gaussian blur overlay** — generates an alpha mask via `geq` where the centre is fully opaque and it linearly fades to transparent at the outer radius, then composites a slightly-blurred version of the same corner on top through that mask. This hides the sharp transition between interpolated and original pixels.

That's the whole thing. Open `delogo.sh` and read it — it's ~80 lines.

## Limitations

- **Top-left badge only** by default — change `LOGO_X/Y` for other corners.
- **Per-frame interpolation, no temporal coherence.** On detailed/textured backgrounds the patch may visibly "breathe" between frames. With handheld/shaky footage the noise hides it perfectly.
- **Not for moving watermarks** that pan across the frame.
- **Re-encodes video.** Small generation loss at CRF 18 — practically invisible. Audio is copied losslessly.

## Why not AI?

Short answer: this is a static, fixed-position badge over a small area. Classic interpolation handles it instantly with zero hardware requirements. AI inpainting (ProPainter, LaMa, RunwayML Erase & Replace) is *better* on dynamic / complex / large watermarks but takes 10×–100× longer, needs a GPU or a paid API, and is overkill here.

Use **this script (FFmpeg `delogo`)** when:
- The watermark is in a fixed position
- It covers a small area (<10% of the frame)
- The background under it is reasonably uniform OR the footage moves enough to hide soft patches
- You want a 30-second turnaround on a laptop

Use **AI inpainting** (RunwayML, ProPainter, Topaz Video AI) when:
- The watermark moves, animates, or pulses
- It covers a large area or sits over fine detail (faces, text, intricate textures)
- You're delivering high-end work where the patch will get scrutinized at 4K
- You're willing to pay / wait

## License

MIT. Use it, fork it, ship it. Credit appreciated but not required.

## Credits

Built by [@olegpars](https://github.com/olegpars). FFmpeg does 99% of the actual work — go support [the FFmpeg project](https://ffmpeg.org/donations.html).
