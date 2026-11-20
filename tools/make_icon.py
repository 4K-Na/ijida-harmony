"""
生成 i集大 鸿蒙版应用图标（品牌红渐变 + 白色「集」字）
输出：
  AppScope/resources/base/media/app_icon.png           1024x1024
  entry/src/main/resources/base/media/startIcon.png     1024x1024（启动图标）
  entry/src/main/resources/base/media/foreground.png    1024x1024（分层图标前景，留安全边距）
"""
from PIL import Image, ImageDraw, ImageFont
import os, math

ROOT = r"C:\Users\myr\Documents\AI workspace\ijida-harmony"
W = H = 1024
C1 = (242, 104, 63)     # #F2683F
C2 = (232, 64, 38)      # #E84026


def gradient(size, c1, c2):
    """135° 线性渐变"""
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2.0
            px[x, y] = (
                int(c1[0] + (c2[0] - c1[0]) * t),
                int(c1[1] + (c2[1] - c1[1]) * t),
                int(c1[2] + (c2[2] - c1[2]) * t),
            )
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def load_font(px):
    for cand in [
        r"C:\Windows\Fonts\msyhbd.ttc",
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
    ]:
        if os.path.exists(cand):
            try:
                return ImageFont.truetype(cand, px)
            except Exception:
                continue
    return ImageFont.load_default()


def make_icon(out_path, with_round_corner=True, radius=230, glyph="集", glyph_ratio=0.52, pad=0):
    base = gradient((W, H), C1, C2)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if with_round_corner:
        img.paste(base, (0, 0), rounded_mask((W, H), radius))
    else:
        img.paste(base, (0, 0))

    d = ImageDraw.Draw(img)
    font = load_font(int(W * glyph_ratio))
    bbox = d.textbbox((0, 0), glyph, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (W - tw) / 2 - bbox[0]
    ty = (H - th) / 2 - bbox[1] + pad
    d.text((tx, ty), glyph, font=font, fill=(255, 255, 255, 255))

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    print("wrote", out_path, img.size)


# 1) 桌面图标
make_icon(os.path.join(ROOT, r"AppScope\resources\base\media\app_icon.png"))

# 2) 启动图标（同样式，方形不裁角，避免启动窗被二次裁切）
make_icon(
    os.path.join(ROOT, r"entry\src\main\resources\base\media\startIcon.png"),
    with_round_corner=False,
)

# 3) 分层图标前景（鸿蒙要求前景留安全区，图形缩小到 60% 居中）
fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
inner = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(inner)
font = load_font(int(W * 0.34))
bbox = d.textbbox((0, 0), "集", font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
d.text(((W - tw) / 2 - bbox[0], (H - th) / 2 - bbox[1]), "集", font=font, fill=(255, 255, 255, 255))
fg.alpha_composite(inner)
os.makedirs(os.path.join(ROOT, r"entry\src\main\resources\base\media"), exist_ok=True)
fg.save(os.path.join(ROOT, r"entry\src\main\resources\base\media\foreground.png"), "PNG")
print("wrote foreground.png")
