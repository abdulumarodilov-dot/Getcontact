#!/usr/bin/env python3
"""Ilova ikonkalari va yuklash ekrani rasmini vektordan yasaydi.

Ishlatish (loyiha ildizidan):
    pip install cairosvg pillow
    python3 tool/make_icons.py

Natija (assets/):
    icon_ios.png        1024x1024, RGB  — iOS ikonkasi (shaffofliksiz)
    icon.png            1024x1024, RGB  — Android oddiy (eski) ikonkasi
    icon_android_fg.png 1024x1024, RGBA — Android adaptiv ikonkasi (old qatlam)
    icon_android_bg.png 1024x1024, RGB  — Android adaptiv ikonkasi (fon)
    splash_logo.png     1024x1024, RGB  — yuklash ekrani (fon #05193F)

Belgi: yumaloq romb (superellips) ichida lupa, lupa ichida signal
to'lqinli telefon go'shagi. Hammasi vektor: belgi har bir rasm uchun
to'g'ridan-to'g'ri kerakli o'lchamda chiziladi (rastr kattalashtirilmaydi),
2x kattalikda chizilib keyin kichraytiriladi — chekkalar silliq chiqadi.

Shakl foydalanuvchi bergan ikonkadan o'lchab olingan; go'shak konturi
o'sha rasmdan silliq spline bilan ko'chirilgan.
"""

import io
import math
import os
import sys

import cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SS = 2                      # supersampling
BIG = SIZE * SS
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')

SPLASH_BG = (0x05, 0x19, 0x3F)  # pubspec.yaml: flutter_native_splash.color

# Go'shak — foydalanuvchi bergan ikonkadan aniq ko'chirilgan kontur
# (birlikda, (0,0) — linza markazi; silliqlangan spline).
HANDSET = (
    'M -53.4 209.7 L -58.2 210.2 L -63.0 210.5 L -67.9 210.6 L -72.8 210.5 L -77.7 210.1 L -82.5 209.5 L -87.3 208.6 L -92.0 207.4 L -96.6 206.0 L -101.1 204.4 L -105.5 202.4 L -109.8 200.3 L -114.0 197.9 L -118.0 195.3 L -122.0 192.5 L -125.9 189.6 L -129.8 186.6 L -133.6 183.6 L -137.3 180.4 L -141.0 177.2 L -144.6 173.9 L -148.2 170.5 L -151.6 167.0 L -155.0 163.4 L -158.2 159.7 L -161.3 155.7 L -164.2 151.7 L -166.7 147.5 L -168.5 143.1 L -169.4 138.6 L -169.4 134.0 L -168.6 129.3 L -167.1 124.6 L -165.2 120.1 L -162.9 115.7 L -160.5 111.6 L -157.8 107.6 L -154.9 103.8 L -151.8 100.2 L -148.5 96.8 L -145.1 93.4 L -141.6 90.2 L -137.9 87.1 L -134.0 84.1 L -130.1 81.2 L -126.1 78.3 L -122.0 75.5 L -117.8 72.7 L -113.6 69.9 L -109.3 67.2 L -105.0 64.5 L -100.7 61.9 L -96.4 59.6 L -92.0 57.7 L -87.7 56.2 L -83.4 55.2 L -79.1 55.0 L -74.8 55.5 L -70.6 57.0 L -66.5 59.3 L -62.4 62.2 L -58.7 65.7 L -55.2 69.4 L -51.9 73.3 L -48.7 77.2 L -45.4 81.1 L -42.0 84.6 L -38.2 87.8 L -34.2 90.5 L -30.0 92.5 L -25.5 93.8 L -20.9 94.2 L -16.2 93.9 L -11.6 93.0 L -7.1 91.4 L -2.9 89.3 L 1.1 86.8 L 5.0 83.8 L 8.7 80.5 L 12.3 77.1 L 15.8 73.4 L 19.2 69.8 L 22.6 66.1 L 26.0 62.5 L 29.4 58.9 L 32.8 55.4 L 36.2 51.9 L 39.5 48.4 L 42.9 44.9 L 46.4 41.5 L 49.8 38.1 L 53.2 34.7 L 56.7 31.3 L 60.2 27.9 L 63.8 24.6 L 67.3 21.2 L 70.9 17.8 L 74.6 14.4 L 78.3 10.9 L 81.9 7.4 L 85.4 3.9 L 88.6 0.2 L 91.5 -3.7 L 94.1 -7.7 L 96.1 -12.0 L 97.6 -16.5 L 98.4 -21.2 L 98.6 -25.9 L 98.2 -30.7 L 97.0 -35.2 L 95.0 -39.5 L 92.4 -43.4 L 89.3 -47.1 L 85.7 -50.5 L 81.9 -53.9 L 78.0 -57.2 L 74.1 -60.5 L 70.4 -63.8 L 67.0 -67.2 L 64.1 -70.8 L 61.8 -74.7 L 60.3 -78.7 L 59.6 -83.1 L 59.8 -87.8 L 60.7 -92.6 L 62.3 -97.4 L 64.3 -102.1 L 66.6 -106.5 L 69.2 -110.8 L 71.9 -114.9 L 74.7 -118.8 L 77.5 -122.8 L 80.3 -126.7 L 83.2 -130.5 L 86.1 -134.3 L 89.0 -138.1 L 92.0 -141.9 L 95.1 -145.6 L 98.3 -149.3 L 101.6 -153.0 L 105.0 -156.5 L 108.6 -159.9 L 112.4 -163.1 L 116.4 -166.0 L 120.5 -168.5 L 124.9 -170.5 L 129.5 -172.1 L 134.3 -173.1 L 139.2 -173.5 L 144.1 -173.3 L 148.7 -172.4 L 153.1 -170.7 L 157.2 -168.4 L 161.1 -165.6 L 164.8 -162.5 L 168.4 -159.2 L 172.1 -155.9 L 175.7 -152.6 L 179.3 -149.2 L 182.8 -145.7 L 186.2 -142.1 L 189.5 -138.5 L 192.6 -134.7 L 195.6 -130.8 L 198.3 -126.7 L 200.8 -122.6 L 203.2 -118.3 L 205.3 -113.9 L 207.2 -109.5 L 208.9 -105.0 L 210.5 -100.4 L 211.8 -95.7 L 212.9 -91.1 L 213.7 -86.3 L 214.4 -81.6 L 214.8 -76.8 L 215.1 -72.0 L 215.1 -67.2 L 214.8 -62.5 L 214.4 -57.7 L 213.7 -53.0 L 212.8 -48.4 L 211.6 -43.7 L 210.2 -39.2 L 208.7 -34.6 L 207.0 -30.1 L 205.0 -25.7 L 202.9 -21.3 L 200.7 -16.9 L 198.3 -12.7 L 195.8 -8.4 L 193.2 -4.2 L 190.5 -0.1 L 187.7 4.0 L 184.8 8.0 L 181.8 11.9 L 178.7 15.8 L 175.7 19.6 L 172.5 23.4 L 169.4 27.1 L 166.2 30.8 L 162.9 34.4 L 159.6 38.0 L 156.3 41.5 L 153.0 45.0 L 149.7 48.5 L 146.3 52.0 L 142.9 55.4 L 139.5 58.9 L 136.1 62.3 L 132.6 65.7 L 129.2 69.2 L 125.7 72.6 L 122.2 76.0 L 118.8 79.5 L 115.3 83.0 L 111.8 86.4 L 108.3 89.9 L 104.8 93.4 L 101.3 96.9 L 97.9 100.4 L 94.4 103.9 L 90.9 107.4 L 87.4 110.9 L 83.9 114.3 L 80.4 117.8 L 77.0 121.3 L 73.5 124.8 L 70.0 128.3 L 66.6 131.7 L 63.1 135.2 L 59.7 138.6 L 56.2 142.0 L 52.7 145.4 L 49.2 148.8 L 45.7 152.1 L 42.1 155.4 L 38.5 158.7 L 34.9 161.9 L 31.2 165.1 L 27.5 168.3 L 23.8 171.3 L 20.0 174.4 L 16.1 177.4 L 12.2 180.3 L 8.2 183.1 L 4.2 185.9 L 0.1 188.5 L -4.0 191.1 L -8.2 193.6 L -12.5 195.9 L -16.8 198.1 L -21.2 200.1 L -25.6 202.0 L -30.1 203.8 L -34.6 205.3 L -39.2 206.7 L -43.9 207.9 L -48.6 208.9 Z'
)

# ── Belgi geometriyasi (birlik; (0,0) — linza markazi) ────────────
SHAPE_C = (0, 0)        # romb markazi (linza bilan bir markazli)
SHAPE_A = 443           # romb tomonigacha masofa (diagonal bo'yicha)
SHAPE_N = 2.5           # superellips darajasi: 2 — doira, kattasi — kvadratga yaqin
LENS_R = 309            # oq linza radiusi
SHADOW = (-4, 36)       # linza soyasining siljishi (asosan pastga)

HANDLE_W = 102          # bo'yin va dasta qalinligi
NECK_END = 439          # oq bo'yin tugaydigan joy (diagonal bo'yicha)
HANDLE_START = 449      # tirqishdan keyin dasta boshlanadi
HANDLE_TIP = 617        # dasta uchi

WAVES_C = (15, 17.5)    # to'lqinlar markazi
WAVES_R = (116, 168.5, 220)
WAVE_W = 22             # asl rasmdagidan biroz qalin — kichik o'lchamda ko'rinadi

def diag(d):
    k = d / math.sqrt(2)
    return round(k, 2), round(k, 2)


def shape_edge_on_diag():
    """Romb chegarasining dasta yo'nalishidagi nuqtasi (linzadan masofa)."""
    return SHAPE_A + (SHAPE_C[0] + SHAPE_C[1]) / math.sqrt(2)


def shape_path(steps=720):
    """45° ga burilgan superellips."""
    pts = []
    rot = math.radians(45)
    cr, sr = math.cos(rot), math.sin(rot)
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        x = SHAPE_A * math.copysign(abs(c) ** (2 / SHAPE_N), c)
        y = SHAPE_A * math.copysign(abs(s) ** (2 / SHAPE_N), s)
        X = x * cr - y * sr + SHAPE_C[0]
        Y = x * sr + y * cr + SHAPE_C[1]
        pts.append(f'{X:.2f} {Y:.2f}')
    return 'M ' + ' L '.join(pts) + ' Z'


def glyph_body():
    nx0, ny0 = diag(0)
    nx1, ny1 = diag(NECK_END)

    # Dasta: tekis boshlanadi, uchi yumaloq
    h = HANDLE_W / 2
    k = h / math.sqrt(2)              # perpendikulyar (1,-1)/sqrt2 * h
    sx, sy = diag(HANDLE_START)
    ex, ey = diag(HANDLE_TIP - h)
    tx, ty = diag(HANDLE_TIP)
    handle = (f'M {sx + k:.1f} {sy - k:.1f} L {ex + k:.1f} {ey - k:.1f} '
              f'A {h} {h} 0 0 1 {ex - k:.1f} {ey + k:.1f} '
              f'L {sx - k:.1f} {sy + k:.1f} Z')

    cx, cy = WAVES_C
    arcs = []
    for r in WAVES_R:
        a0, a1 = math.radians(180), math.radians(270)
        x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
        x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
        arcs.append(f'M {x0:.1f} {y0:.1f} A {r} {r} 0 0 1 {x1:.1f} {y1:.1f}')

    shape = shape_path()
    sdx, sdy = SHADOW

    return f'''
  <defs>
    <clipPath id="shape"><path d="{shape}"/></clipPath>
    <linearGradient id="blue" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#3A7BEB"/>
      <stop offset="0.55" stop-color="#2461D2"/>
      <stop offset="1" stop-color="#1B4FB8"/>
    </linearGradient>
    <linearGradient id="handle" gradientUnits="userSpaceOnUse"
                    x1="{sx}" y1="{sy}" x2="{tx}" y2="{ty}">
      <stop offset="0" stop-color="#2865D8"/>
      <stop offset="1" stop-color="#1A4BB0"/>
    </linearGradient>
    <linearGradient id="ink" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2F6EE2"/>
      <stop offset="1" stop-color="#1D52BE"/>
    </linearGradient>
    <radialGradient id="glass" cx="0.42" cy="0.36" r="0.72">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.8" stop-color="#FAFCFF"/>
      <stop offset="1" stop-color="#EAF1FF"/>
    </radialGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.16"/>
      <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <!-- yumaloq romb -->
  <path d="{shape}" fill="url(#blue)"/>
  <path d="{shape}" fill="url(#sheen)"/>

  <g clip-path="url(#shape)">
    <!-- linza va bo'yin soyasi -->
    <g transform="translate({sdx} {sdy})" opacity="0.55">
      <circle r="{LENS_R}" fill="#0F347F"/>
      <line x1="{nx0}" y1="{ny0}" x2="{nx1}" y2="{ny1}" stroke="#0F347F"
            stroke-width="{HANDLE_W}" stroke-linecap="butt"/>
    </g>
    <!-- oq bo'yin: linzadan romb chetigacha -->
    <line x1="{nx0}" y1="{ny0}" x2="{nx1}" y2="{ny1}" stroke="#F3F7FF"
          stroke-width="{HANDLE_W}" stroke-linecap="butt"/>
  </g>

  <!-- oq linza -->
  <circle r="{LENS_R}" fill="url(#glass)"/>

  <!-- dasta: tirqishdan keyin, uchi yumaloq -->
  <path d="{handle}" fill="url(#handle)"/>

  <!-- signal to'lqinlari -->
  <path d="{' '.join(arcs)}" fill="none" stroke="url(#ink)"
        stroke-width="{WAVE_W}" stroke-linecap="round"/>

  <!-- go'shak -->
  <path d="{HANDSET}" fill="url(#ink)"/>
'''


def glyph_layer(px_per_unit, anchor, at):
    """Belgini BIG x BIG shaffof tuvalga to'g'ridan-to'g'ri vektordan chizadi.

    px_per_unit — 1 birlik necha piksel (BIG tuvalda)
    anchor      — belgidagi qaysi nuqta (birlikda)
    at          — tuvalning qaysi nuqtasiga tushadi (pikselda, BIG)
    """
    ax, ay = anchor
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{BIG}" height="{BIG}" '
           f'viewBox="0 0 {BIG} {BIG}">'
           f'<g transform="translate({at[0]} {at[1]}) scale({px_per_unit}) '
           f'translate({-ax} {-ay})">{glyph_body()}</g></svg>')
    png = cairosvg.svg2png(bytestring=svg.encode('utf-8'))
    return Image.open(io.BytesIO(png)).convert('RGBA')


def add_shadow(layer, strength=0.45):
    """Belgi ostiga yumshoq soya."""
    box = layer.getbbox()
    size = max(box[2] - box[0], box[3] - box[1]) if box else BIG
    a = layer.getchannel('A').point(lambda v: int(v * strength))
    sh = Image.new('RGBA', layer.size, (2, 8, 24, 0))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(max(2, int(size * 0.03))))
    out = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (0, int(size * 0.022)))
    out.alpha_composite(layer)
    return out


# Belgining chegaralari (birlikda): romb uchlari va dasta uchi
def extents():
    edge_axis = SHAPE_A * 2 ** (0.5 - 1 / SHAPE_N)   # romb uchi (o'qlar bo'yicha)
    tip = diag(HANDLE_TIP)[0]
    left = SHAPE_C[0] - edge_axis
    top = SHAPE_C[1] - edge_axis
    right = max(SHAPE_C[0] + edge_axis, tip)
    bottom = max(SHAPE_C[1] + edge_axis, tip)
    return left, top, right, bottom


def enclosing_circle():
    """Rombni va dastani o'rab oluvchi eng kichik doira (taxminiy)."""
    edge_axis = SHAPE_A * 2 ** (0.5 - 1 / SHAPE_N)
    tipd = HANDLE_TIP
    best = None
    for i in range(0, 200):
        t = i  # markazni diagonal bo'yicha siljitamiz
        c = (SHAPE_C[0] + t / math.sqrt(2), SHAPE_C[1] + t / math.sqrt(2))
        pts = [(SHAPE_C[0] - edge_axis, SHAPE_C[1]), (SHAPE_C[0], SHAPE_C[1] - edge_axis),
               (SHAPE_C[0] + edge_axis, SHAPE_C[1]), (SHAPE_C[0], SHAPE_C[1] + edge_axis),
               diag(tipd)]
        # romb tomonlari (yuqori-chap diagonal)
        k = SHAPE_A / math.sqrt(2)
        pts.append((SHAPE_C[0] - k, SHAPE_C[1] - k))
        r = max(math.hypot(p[0] - c[0], p[1] - c[1]) for p in pts)
        if best is None or r < best[1]:
            best = (c, r)
    return best


def render_bg():
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{BIG}" height="{BIG}" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0B2E6E"/>
      <stop offset="0.55" stop-color="#05193F"/>
      <stop offset="1" stop-color="#020A1F"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.48" r="0.5">
      <stop offset="0" stop-color="#2F74E8" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#2F74E8" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>
</svg>'''
    png = cairosvg.svg2png(bytestring=svg.encode('utf-8'))
    return Image.open(io.BytesIO(png)).convert('RGBA')


def down(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def font(paths, size):
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    os.makedirs(ASSETS, exist_ok=True)
    bg = render_bg()

    l, t, r, b = extents()
    w, h = r - l, b - t
    bbox_c = ((l + r) / 2, (t + b) / 2)

    # ── iOS va oddiy Android ikonkasi: to'liq kvadrat, shaffofliksiz ──
    # Belgi tuvalning 80% ini egallaydi.
    ppu = BIG * 0.80 / max(w, h)
    icon = bg.copy()
    icon.alpha_composite(add_shadow(glyph_layer(ppu, bbox_c, (BIG / 2, BIG / 2))))
    icon = down(icon).convert('RGB')
    icon.save(os.path.join(ASSETS, 'icon_ios.png'), optimize=True)
    icon.save(os.path.join(ASSETS, 'icon.png'), optimize=True)

    # ── Android adaptiv ikonkasi ──
    # Har qanday shakl (doira, kvadrat, tomchi) uchun xavfsiz doira —
    # diametri tuvalning 61% i (66dp / 108dp). Butun belgi shu doiraga sig'adi.
    (cx, cy), rad = enclosing_circle()
    ppu_a = (BIG * 0.61 / 2) / rad
    fg = add_shadow(glyph_layer(ppu_a, (cx, cy), (BIG / 2, BIG / 2)), 0.35)
    down(fg).save(os.path.join(ASSETS, 'icon_android_fg.png'), optimize=True)
    down(bg).convert('RGB').save(os.path.join(ASSETS, 'icon_android_bg.png'),
                                 optimize=True)

    # ── Yuklash ekrani: bir xil rangli fon (#05193F), belgi + nom ──
    splash = Image.new('RGBA', (BIG, BIG), SPLASH_BG + (255,))
    gc = (BIG / 2, BIG * 0.335)
    halo = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    hr = BIG * 0.23
    ImageDraw.Draw(halo).ellipse((gc[0] - hr, gc[1] - hr, gc[0] + hr, gc[1] + hr),
                                 fill=(47, 116, 232, 60))
    splash.alpha_composite(halo.filter(ImageFilter.GaussianBlur(int(BIG * 0.07))))
    ppu_s = BIG * 0.40 / max(w, h)
    splash.alpha_composite(add_shadow(glyph_layer(ppu_s, bbox_c, gc), 0.5))

    d = ImageDraw.Draw(splash)
    title = font(['/usr/share/fonts/opentype/inter/Inter-Bold.otf',
                  'Inter-Bold.ttf', 'DejaVuSans-Bold.ttf'], 104 * SS)
    sub = font(['/usr/share/fonts/opentype/inter/Inter-Medium.otf',
                'Inter-Medium.ttf', 'DejaVuSans.ttf'], 44 * SS)
    d.text((BIG / 2, 690 * SS), 'Getcontact', font=title,
           fill=(255, 255, 255), anchor='mm')
    d.text((BIG / 2, 774 * SS), "Ma'lumotlar qidiruvi", font=sub,
           fill=(140, 184, 242), anchor='mm')
    down(splash).convert('RGB').save(os.path.join(ASSETS, 'splash_logo.png'),
                                     optimize=True)

    print('Tayyor:', ', '.join(sorted(
        f for f in os.listdir(ASSETS) if f.endswith('.png'))))


if __name__ == '__main__':
    sys.exit(main())
