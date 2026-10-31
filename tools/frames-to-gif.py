# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10"]
# ///
"""Turns the frames record-demo.ps1 grabbed (<elapsed ms>.png) into an optimized GIF.

    uv run tools/frames-to-gif.py <frames dir> <out.gif> [width]
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops

src, out = Path(sys.argv[1]), Path(sys.argv[2])
width = int(sys.argv[3]) if len(sys.argv) > 3 else 960
files = sorted(src.glob('*.png'), key=lambda p: int(p.stem))
stamps = [int(p.stem) for p in files]

frames, durations = [], []
for i, f in enumerate(files):
    im = Image.open(f).convert('RGB')
    im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    ms = (stamps[i + 1] - stamps[i]) if i + 1 < len(files) else 2500
    if frames and not ImageChops.difference(frames[-1], im).getbbox():
        durations[-1] += ms
    else:
        frames.append(im)
        durations.append(ms)

# one palette for every frame keeps unchanged regions identical, so each frame stores only what changed
sample = frames[:: max(1, len(frames) // 24)]
mosaic = Image.new('RGB', (width, sum(f.height for f in sample)))
y = 0
for f in sample:
    mosaic.paste(f, (0, y))
    y += f.height
palette = mosaic.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
gif = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
gif[0].save(out, save_all=True, append_images=gif[1:], duration=[max(20, d) for d in durations], loop=0, optimize=False, disposal=1)
print(f'{out}: {len(gif)} frames, {sum(durations) / 1000:.1f} s, {out.stat().st_size / 1024 / 1024:.1f} MB')
