"""Dibuja las operaciones de preview.js con Pillow. Uso: python3 render.py ops.json out.png [escala] [x0 y0 x1 y1]"""
import json, sys
from PIL import Image, ImageDraw, ImageFont
ops = json.load(open(sys.argv[1])); scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.25
xs = [o["x"] + o.get("w", 0) for o in ops]; ys = [o["y"] + o.get("h", 0) for o in ops]
if len(sys.argv) > 7: X0, Y0, X1, Y1 = map(float, sys.argv[4:8])
else: X0, Y0, X1, Y1 = min(o["x"] for o in ops) - 40, min(o["y"] for o in ops) - 40, max(xs) + 40, max(ys) + 40
W, H = int((X1 - X0) * scale), int((Y1 - Y0) * scale)
img = Image.new("RGB", (max(W, 10), max(H, 10)), "#1E1E1E"); d = ImageDraw.Draw(img, "RGBA")
fonts = {}
def font(size, bold):
    k = (int(size), bold)
    if k not in fonts:
        path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        try: fonts[k] = ImageFont.truetype(path, max(6, int(size)))
        except Exception: fonts[k] = ImageFont.load_default()
    return fonts[k]
def P(x, y): return ((x - X0) * scale, (y - Y0) * scale)
for o in ops:
    if o["x"] > X1 or o["y"] > Y1 or o["x"] + o.get("w", 0) < X0 or o["y"] + o.get("h", 0) < Y0: continue
    x0, y0 = P(o["x"], o["y"]); x1, y1 = P(o["x"] + o["w"], o["y"] + o["h"])
    if x1 < x0 + 0.5: x1 = x0 + 0.5
    if y1 < y0 + 0.5: y1 = y0 + 0.5
    if o["t"] == "rect":
        fill = None
        if o.get("fill"):
            c = o["fill"].lstrip("#"); fill = tuple(int(c[i:i+2], 16) for i in (0, 2, 4)) + (int(255 * o.get("op", 1)),)
        d.rounded_rectangle([x0, y0, x1, y1], radius=o.get("r", 0) * scale, fill=fill, outline=o.get("stroke"), width=max(1, int(o.get("sw", 1) * scale)) if o.get("stroke") else 0)
    elif o["t"] == "icon":
        d.rectangle([x0, y0, x1, y1], outline="#8A929B")
    elif o["t"] == "text":
        f = font(o["size"] * scale, o["bold"]); text = o["s"]
        if o.get("wrap"):
            words, lines, cur = text.split(" "), [], ""
            for w in words:
                t = (cur + " " + w).strip()
                if d.textlength(t, font=f) > (x1 - x0) and cur: lines.append(cur); cur = w
                else: cur = t
            lines.append(cur); text = "\n".join(lines)
        d.multiline_text((x0, y0), text, fill=o["color"], font=f, spacing=2)
        if o.get("strike"): d.line([x0, (y0 + y1) / 2, x1, (y0 + y1) / 2], fill=o["color"])
img.save(sys.argv[2]); print("guardado", sys.argv[2], img.size)
