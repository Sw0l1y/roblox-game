"""Cut ChatGPT-generated icon sheets (4x4 grids) into single 512px icons for upload.

Usage: python3 games/crystal/tools/crop.py <art-dir>
<art-dir> holds sheetA.png, sheetB.png, sheetC.png. Writes games/crystal/art/icons/<name>.png.
Backgrounds that aren't transparent (flat magenta or any flat color) are keyed out from the cell corners.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT = pathlib.Path(__file__).resolve().parents[1] / "art" / "icons"
SHEETS = {
    "sheetA.png": ["coins", "chest", "vault", "fastgrow", "lucky", "sellanywhere", "vip", "starter",
                   "growall", "restock", "frost", "thunder", "meteor", "aurora", "shop", "seeds"],
    "sheetB.png": ["backpack", "index", "daily", "gift", "garden", "sell", "shovel", "music",
                   "mute", "plus", "quartz", "amethyst", "citrine", "emerald", "sapphire", "ruby"],
    "sheetC.png": ["topaz", "opal", "moonstone", "starfire", "void", "prism"],
}


def key_out(cell):
    """Make the flat background transparent (if the cell has no alpha already)."""
    a = np.array(cell.convert("RGBA")).astype(np.int32)
    if a[..., 3].min() < 250:
        return Image.fromarray(a.astype(np.uint8), "RGBA")
    h, w = a.shape[:2]
    corners = np.concatenate([a[:6, :6, :3].reshape(-1, 3), a[:6, -6:, :3].reshape(-1, 3),
                              a[-6:, :6, :3].reshape(-1, 3), a[-6:, -6:, :3].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((a[..., :3] - bg) ** 2).sum(-1))
    # flood fill from the border so background-coloured pixels inside the icon survive
    near = dist < 60
    mask = np.zeros((h, w), bool)
    stack = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and near[y, x] and not mask[y, x]:
            mask[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    alpha = np.array(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(1.2)))
    # pull the background tint out of the soft edge pixels
    a[..., 3] = np.minimum(alpha, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def square(img, size=512, pad=0.06):
    box = img.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    if box:
        img = img.crop(box)
    w, h = img.size
    side = int(max(w, h) * (1 + pad * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - w) // 2, (side - h) // 2), img)
    return canvas.resize((size, size), Image.LANCZOS)


def main():
    src = pathlib.Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet, names in SHEETS.items():
        path = src / sheet
        if not path.exists():
            print("missing", path)
            continue
        img = Image.open(path).convert("RGBA")
        cw, ch = img.width / 4, img.height / 4
        for i, name in enumerate(names):
            x, y = i % 4, i // 4
            # trim a little so neighbouring cells never bleed in
            cell = img.crop((int(x * cw + cw * 0.02), int(y * ch + ch * 0.02), int((x + 1) * cw - cw * 0.02), int((y + 1) * ch - ch * 0.02)))
            square(key_out(cell)).save(OUT / f"{name}.png")
        print("cut", sheet, len(names), "icons")


if __name__ == "__main__":
    main()
