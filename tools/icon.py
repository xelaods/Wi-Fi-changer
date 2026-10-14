"""アプリアイコン（1024x1024）を作る：青のグラデーションに白い Wi-Fi マークと、切り替えの矢印"""
import math
import sys
from PIL import Image, ImageDraw

S = 1024
SS = 3  # なめらかにするため大きく描いて縮める
W = S * SS


def gradient(top, bottom):
    img = Image.new("RGB", (W, W), top)
    d = ImageDraw.Draw(img)
    for y in range(W):
        t = y / (W - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (W, y)], fill=c)
    return img


img = gradient((72, 166, 255), (0, 98, 232))
d = ImageDraw.Draw(img)
white = (255, 255, 255)

# Wi-Fi マーク（中心を下寄りに）
cx, cy = W / 2, 610 * SS
stroke = 84 * SS
for r in (380, 230):
    r *= SS
    box = (cx - r, cy - r, cx + r, cy + r)
    d.arc(box, start=225, end=315, fill=white, width=stroke)
    # 端を丸める
    for ang in (225, 315):
        a = math.radians(ang)
        rr = r - stroke / 2
        px, py = cx + rr * math.cos(a), cy + rr * math.sin(a)
        d.ellipse((px - stroke / 2, py - stroke / 2, px + stroke / 2, py + stroke / 2), fill=white)
dot = 60 * SS
d.ellipse((cx - dot, cy - dot, cx + dot, cy + dot), fill=white)

# 切り替えの矢印（下）
def arrow(y, left_to_right):
    x0, x1 = 330 * SS, 694 * SS
    h = 30 * SS
    d.rounded_rectangle((x0, y - h / 2, x1, y + h / 2), radius=h / 2, fill=(255, 255, 255, 230))
    head = 62 * SS
    if left_to_right:
        d.polygon([(x1 + 34 * SS, y), (x1 - head + 20 * SS, y - head * 0.9), (x1 - head + 20 * SS, y + head * 0.9)], fill=white)
    else:
        d.polygon([(x0 - 34 * SS, y), (x0 + head - 20 * SS, y - head * 0.9), (x0 + head - 20 * SS, y + head * 0.9)], fill=white)

arrow(775 * SS, True)
arrow(860 * SS, False)

img = img.resize((S, S), Image.LANCZOS)
out = sys.argv[1] if len(sys.argv) > 1 else "WiFiChanger/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
img.save(out)
print("saved", out)
