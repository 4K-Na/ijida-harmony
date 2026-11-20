"""应用 B 方案（字母 i）作为正式图标，并生成分层资源"""
from PIL import Image, ImageDraw
import math, os

S = 1024
C1 = (91, 140, 255)
C2 = (46, 91, 224)
ROOT = r"C:\Users\myr\Documents\AI workspace\ijida-harmony"


def gradient(size):
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    a = math.radians(135)
    dx, dy = math.cos(a), math.sin(a)
    projs = [0, w * dx, h * dy, w * dx + h * dy]
    pmin, pmax = min(projs), max(projs)
    span = (pmax - pmin) or 1
    for y in range(h):
        for x in range(w):
            t = max(0.0, min(1.0, ((x * dx + y * dy) - pmin) / span))
            px[x, y] = (int(C1[0] + (C2[0] - C1[0]) * t),
                        int(C1[1] + (C2[1] - C1[1]) * t),
                        int(C1[2] + (C2[2] - C1[2]) * t))
    return img


def glyph(size, scale=1.0, color=(255, 255, 255, 255)):
    """字母 i：圆点 + 圆角竖条"""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    s = size[0]
    # 圆点
    r = int(s * 0.094 * scale)
    cx = s // 2
    dot_cy = int(s * (0.5 - 0.200 * scale))
    d.ellipse([cx - r, dot_cy - r, cx + r, dot_cy + r], fill=color)
    # 竖条（与圆点留出明显间隙）
    bar_w = int(s * 0.132 * scale)
    bar_top = int(s * (0.5 - 0.060 * scale))
    bar_bot = int(s * (0.5 + 0.290 * scale))
    d.rounded_rectangle([cx - bar_w // 2, bar_top, cx + bar_w // 2, bar_bot],
                        radius=bar_w // 2, fill=color)
    return layer


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


# 1) 桌面图标
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
icon.paste(gradient((S, S)), (0, 0), rounded_mask((S, S), 228))
icon.alpha_composite(glyph((S, S), 1.0))
p1 = os.path.join(ROOT, r"AppScope\resources\base\media\app_icon.png")
icon.save(p1, "PNG")
print("app_icon:", p1)

# 2) 分层资源
media = os.path.join(ROOT, r"entry\src\main\resources\base\media")
gradient((S, S)).convert("RGBA").save(os.path.join(media, "background.png"), "PNG")
glyph((S, S), 0.56).save(os.path.join(media, "foreground.png"), "PNG")
print("layers updated:", media)
