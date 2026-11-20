"""生成 3 个图标候选，并输出对比图（含 72px 小尺寸预览）"""
from PIL import Image, ImageDraw
import math, os

S = 1024
C1 = (91, 140, 255)
C2 = (46, 91, 224)
OUT = r"C:\Users\myr\Documents\AI workspace\ijida-harmony\_run"
os.makedirs(OUT, exist_ok=True)


def gradient(size, c1=C1, c2=C2, angle_deg=135):
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    projs = [0, w * dx, h * dy, w * dx + h * dy]
    pmin, pmax = min(projs), max(projs)
    span = (pmax - pmin) or 1
    for y in range(h):
        for x in range(w):
            t = max(0.0, min(1.0, ((x * dx + y * dy) - pmin) / span))
            px[x, y] = (int(c1[0] + (c2[0] - c1[0]) * t),
                        int(c1[1] + (c2[1] - c1[1]) * t),
                        int(c1[2] + (c2[2] - c1[2]) * t))
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def base(corner=True):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    b = gradient((S, S))
    img.paste(b, (0, 0), rounded_mask((S, S), 228) if corner else None)
    return img


# A: 三条横线（列表）
def icon_a():
    img = base()
    d = ImageDraw.Draw(img)
    bar_h, gap = int(S * 0.072), int(S * 0.078)
    total = bar_h * 3 + gap * 2
    y0 = (S - total) // 2
    left = int(S * 0.235)
    for i, w in enumerate([0.40, 0.50, 0.32]):
        bw = int(S * w)
        d.rounded_rectangle([left, y0 + i * (bar_h + gap), left + bw, y0 + i * (bar_h + gap) + bar_h],
                            radius=bar_h // 2, fill=(255, 255, 255, 255))
    return img


# B: 字母 i（圆点 + 竖条）
def icon_b():
    img = base()
    d = ImageDraw.Draw(img)
    r = int(S * 0.098)
    cx, dy_top = S // 2, int(S * 0.255)
    d.ellipse([cx - r, dy_top - r, cx + r, dy_top + r], fill=(255, 255, 255, 255))
    bar_w = int(S * 0.140)
    bar_top, bar_bot = int(S * 0.415), int(S * 0.760)
    d.rounded_rectangle([cx - bar_w // 2, bar_top, cx + bar_w // 2, bar_bot],
                        radius=bar_w // 2, fill=(255, 255, 255, 255))
    return img


# C: 卡片堆叠（两张叠加的圆角矩形 + 顶部高光）
def icon_c():
    img = base()
    d = ImageDraw.Draw(img)
    w_, h_ = int(S * 0.470), int(S * 0.560)
    x0, y0 = (S - w_) // 2, (S - h_) // 2
    # 后面一张（半透明）
    d.rounded_rectangle([x0 + int(S * 0.055), y0 - int(S * 0.030), x0 + w_ + int(S * 0.055), y0 + h_ - int(S * 0.030)],
                        radius=int(S * 0.09), fill=(255, 255, 255, 80))
    # 前面一张
    d.rounded_rectangle([x0, y0, x0 + w_, y0 + h_], radius=int(S * 0.09), fill=(255, 255, 255, 255))
    # 内部三条深蓝短线
    line_col = (46, 91, 224, 255)
    bh = int(h_ * 0.105)
    gap = int(h_ * 0.120)
    for i, wl in enumerate([0.58, 0.42, 0.30]):
        lx = x0 + int(w_ * 0.145)
        ly = y0 + int(h_ * 0.245) + i * (bh + gap)
        d.rounded_rectangle([lx, ly, lx + int(w_ * wl), ly + bh], radius=bh // 2, fill=line_col)
    return img


for name, fn in [('A', icon_a), ('B', icon_b), ('C', icon_c)]:
    img = fn()
    img.save(os.path.join(OUT, f"icon_{name}.png"), "PNG")
    print("saved", name)

# 对比图：大图 320 + 小图 72，横向排列
pad = 40
cell_w, cell_h = 360, 480
sheet = Image.new("RGB", (cell_w * 3 + pad * 4, cell_h + pad * 2 + 60), (250, 248, 244))
d = ImageDraw.Draw(sheet)
for i, name in enumerate(['A', 'B', 'C']):
    big = Image.open(os.path.join(OUT, f"icon_{name}.png")).convert("RGBA").resize((320, 320), Image.LANCZOS)
    small = Image.open(os.path.join(OUT, f"icon_{name}.png")).convert("RGBA").resize((72, 72), Image.LANCZOS)
    x = pad + i * (cell_w + pad)
    sheet.paste(big, (x, pad), big)
    sheet.paste(small, (x + 124, pad + 340), small)
    d.text((x, pad + 424), f"{name}   desktop 72px", fill=(60, 60, 64))
sheet.save(os.path.join(OUT, "icon_compare.png"), "PNG")
print("compare saved")
