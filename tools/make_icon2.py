"""
i集大 应用图标生成

设计：
  - 底色：蓝色线性渐变（#5B8CFF → #2E5BE0），与界面主色一致
  - 主体：三条白色圆角横线（列表 / 卡片意象），长度递减，视觉重心靠左
  - 无文字、无描边，保证 24px 下仍可辨识

输出：
  AppScope/resources/base/media/app_icon.png        1024x1024 桌面图标
  entry/.../media/foreground.png                    1024x1024 分层前景（留安全区）
  entry/.../media/background.png                    1024x1024 分层背景
"""
from PIL import Image, ImageDraw
import os

ROOT = r"C:\Users\myr\Documents\AI workspace\ijida-harmony"
S = 1024
C1 = (91, 140, 255)     # #5B8CFF
C2 = (46, 91, 224)      # #2E5BE0


def gradient(size, c1, c2, angle_deg=135):
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    import math
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    # 归一化投影范围
    projs = [0 * dx + 0 * dy, w * dx + 0 * dy, 0 * dx + h * dy, w * dx + h * dy]
    pmin, pmax = min(projs), max(projs)
    span = (pmax - pmin) or 1
    for y in range(h):
        for x in range(w):
            t = ((x * dx + y * dy) - pmin) / span
            t = max(0.0, min(1.0, t))
            px[x, y] = (
                int(c1[0] + (c2[0] - c1[0]) * t),
                int(c1[1] + (c2[1] - c1[1]) * t),
                int(c1[2] + (c2[2] - c1[2]) * t),
            )
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def bars_layer(size, scale=1.0, center=True):
    """三条白色圆角横线"""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = size
    bar_h = int(h * 0.075 * scale)
    gap = int(h * 0.085 * scale)
    radius = bar_h // 2
    # 三条线的宽度比例
    widths = [0.52, 0.62, 0.44]
    total = bar_h * 3 + gap * 2
    y0 = (h - total) // 2
    x_left = int(w * (0.5 - 0.62 / 2)) if center else int(w * 0.18)
    for i, wr in enumerate(widths):
        bw = int(w * wr * scale)
        y = y0 + i * (bar_h + gap)
        d.rounded_rectangle([x_left, y, x_left + bw, y + bar_h], radius=radius, fill=(255, 255, 255, 255))
    return layer


def make_icon(path, corner=True):
    base = gradient((S, S), C1, C2)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if corner:
        img.paste(base, (0, 0), rounded_mask((S, S), 228))
    else:
        img.paste(base, (0, 0))
    img.alpha_composite(bars_layer((S, S), scale=1.0))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("icon:", path)


def make_layers():
    media = os.path.join(ROOT, r"entry\src\main\resources\base\media")
    # 背景：纯渐变，铺满
    bg = gradient((S, S), C1, C2).convert("RGBA")
    os.makedirs(media, exist_ok=True)
    bg.save(os.path.join(media, "background.png"), "PNG")
    # 前景：图形缩小到 58%，居中，留安全区
    fg = bars_layer((S, S), scale=0.52)
    fg.save(os.path.join(media, "foreground.png"), "PNG")
    print("layers: background.png / foreground.png")


make_icon(os.path.join(ROOT, r"AppScope\resources\base\media\app_icon.png"))
make_layers()
