"""Şifre Kasam uygulama simgesini üretir (lacivert zemin, altın kilit)."""
from PIL import Image, ImageDraw, ImageFont
import os

NAVY = (27, 42, 65, 255)
NAVY_DARK = (17, 27, 43, 255)
GOLD = (212, 165, 55, 255)
GOLD_LIGHT = (240, 200, 100, 255)
SS = 4  # süper örnekleme

def motif(d, cx, cy, s):
    """s: motifin genişliği (piksel)."""
    u = s / 100.0
    # Kilit halkası (shackle)
    d.arc([cx - 30*u, cy - 62*u, cx + 30*u, cy - 2*u], 180, 360, fill=GOLD, width=int(13*u))
    d.rectangle([cx - 30*u, cy - 33*u, cx - 17*u, cy - 5*u], fill=GOLD)
    d.rectangle([cx + 17*u, cy - 33*u, cx + 30*u, cy - 5*u], fill=GOLD)
    # Gövde
    d.rounded_rectangle([cx - 46*u, cy - 10*u, cx + 46*u, cy + 58*u], radius=14*u, fill=GOLD)
    # Üst parlak şerit
    d.rounded_rectangle([cx - 40*u, cy - 5*u, cx + 40*u, cy + 2*u], radius=3*u, fill=GOLD_LIGHT)
    # Anahtar deliği
    d.ellipse([cx - 10*u, cy + 10*u, cx + 10*u, cy + 30*u], fill=NAVY_DARK)
    d.polygon([(cx - 5*u, cy + 24*u), (cx + 5*u, cy + 24*u), (cx + 8*u, cy + 44*u), (cx - 8*u, cy + 44*u)], fill=NAVY_DARK)

FONT = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'

def badge(d, S, x0, y0, x1, y1):
    """Sağ alt köşedeki 'İY Labs' etiketi."""
    x0, y0, x1, y1 = x0 * S, y0 * S, x1 * S, y1 * S
    h = y1 - y0
    pad = h * 0.14
    d.rounded_rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], radius=(h + 2 * pad) / 2, fill=NAVY_DARK)
    d.rounded_rectangle([x0, y0, x1, y1], radius=h / 2, fill=GOLD_LIGHT)
    text = 'İY Labs'
    size = int(h * 0.62)
    font = ImageFont.truetype(FONT, size)
    while d.textlength(text, font=font) > (x1 - x0) * 0.84:
        size -= 2
        font = ImageFont.truetype(FONT, size)
    d.text(((x0 + x1) / 2, (y0 + y1) / 2 + h * 0.03), text, font=font, fill=NAVY_DARK, anchor='mm')

def render(size, bg, motif_w, rounded, center=0.5, badge_box=None):
    S = size * SS
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        if rounded:
            d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=NAVY)
        else:
            d.rectangle([0, 0, S, S], fill=NAVY)
        # ince altın çerçeve halkası
        m = S * 0.12
        d.ellipse([m, m, S - m, S - m], outline=(82, 79, 62, 255), width=int(S * 0.012))
    motif(d, S * center, S * center, motif_w * S)
    if badge_box:
        badge(d, S, *badge_box)
    return img.resize((size, size), Image.LANCZOS)

out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
CLASSIC_BADGE = (0.53, 0.79, 0.92, 0.91)
# Uyarlanabilir simgede görünür alan merkezden ~%33 yarıçaplı daire: etiket içeride kalmalı.
ADAPTIVE_BADGE = (0.50, 0.645, 0.73, 0.715)
render(1024, True, 0.54, False, 0.48, CLASSIC_BADGE).save(os.path.join(out, 'icon.png'))
render(1024, False, 0.35, False, 0.475, ADAPTIVE_BADGE).save(os.path.join(out, 'icon_foreground.png'))
render(512, True, 0.54, True, 0.48, CLASSIC_BADGE).save(os.path.join(out, 'preview.png'))
# Daire maskeli telefon görünümü önizlemesi
fg = render(512, False, 0.35, False, 0.475, ADAPTIVE_BADGE)
bgimg = Image.new('RGBA', (512, 512), NAVY)
bgimg.alpha_composite(fg)
mask = Image.new('L', (512, 512), 0)
r = 512 * 0.333
ImageDraw.Draw(mask).ellipse([256 - r, 256 - r, 256 + r, 256 + r], fill=255)
circ = Image.new('RGBA', (512, 512), (255, 255, 255, 255))
circ.paste(bgimg, (0, 0), mask)
circ.crop((int(256 - r), int(256 - r), int(256 + r), int(256 + r))).save(os.path.join(out, 'preview_round.png'))
print('ok')
