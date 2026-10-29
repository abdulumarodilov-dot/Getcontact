#!/usr/bin/env python3
"""Ilova ikonkalari va yuklash ekrani rasmini vektordan yasaydi.

Ishlatish (loyiha ildizidan):
    pip install cairosvg pillow
    python3 tool/make_icons.py          # «halqa» uslubi (to'q ko'k fon)
    python3 tool/make_icons.py romb     # asl dizayn: romb, oq fon

Natija (assets/):
    icon_ios.png        1024x1024, RGB  — iOS ikonkasi (shaffofliksiz)
    icon.png            1024x1024, RGB  — Android oddiy (eski) ikonkasi
    icon_android_fg.png 1024x1024, RGBA — Android adaptiv ikonkasi (old qatlam)
    icon_android_bg.png 1024x1024, RGB  — Android adaptiv ikonkasi (fon)
    splash_logo.png     1024x1024, RGB  — yuklash ekrani (fon #05193F)

Dizayn: to'q ko'k fonda katta ko'k halqali lupa, oq linza ichida signal
to'lqinli go'shak. O'lcham va ranglar foydalanuvchi tanlagan namunadan
olingan; go'shak konturi namunadan silliq spline bilan ko'chirilgan.

Har bir rasm vektordan to'g'ridan-to'g'ri kerakli o'lchamda, 2x kattalikda
chizilib kichraytiriladi — istalgan o'lchamda tiniq. Soyalar Pillow bilan
(cairosvg blur qila olmaydi).
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

# Android adaptiv ikonkasi: lupa markazi AYNAN tuval markazida turadi,
# belgining eng uzoq nuqtasi (dasta uchi) markazdan tuvalning shuncha
# ulushida bo'ladi. Ko'rinadigan doira — 72/108 = 0.333; 0.32 da dasta
# uchi doira chetiga tegmaydi, kvadrat/tomchi shakllarda esa bemalol sig'adi.
ANDROID_TIP = 0.32

# ── Geometriya (birlik: namunadagi piksel; (0,0) — lupa markazi) ──
# Namuna 1254x1254, lupa markazi (619.5, 589.5) — biroz yuqorida, chunki
# dasta pastga-o'ngga chiqadi.
REF_CANVAS = 1254
REF_CENTER = (619.5, 589.5)

RING_R = 459            # ko'k halqaning tashqi radiusi
LINE_R = 329            # halqa va linza orasidagi to'q chiziq (o'rtasi)
LINE_W = 26
LENS_R = 316.5          # oq linza

HANDLE_ANGLE = 46.5     # dasta yo'nalishi (gradus, pastga-o'ngga)
HANDLE_FROM = 290       # linza ostidan boshlanadi
HANDLE_TIP = 617        # uchi (yumaloq)
HANDLE_W = 84

# To'lqinlar: (markaz x, markaz y, radius, boshlanish°, tugash°)
WAVES = [
    (-6.9, 15.3, 121.1, 173.3, 283.5),
    (-2.8, 18.9, 179.8, 176.5, 277.9),
    (4.1, 22.2, 243.1, 178.1, 274.4),
]
WAVE_W = 28

# Go'shak — namunadan ko'chirilgan kontur
HANDSET = (
    'M -39.4 232.3 L -43.7 232.7 L -48.0 233.0 L -52.4 233.1 L -56.8 233.1 '
    'L -61.2 232.9 L -65.6 232.6 L -70.0 232.2 L -74.5 231.7 L -78.9 231.1 '
    'L -83.3 230.3 L -87.7 229.5 L -92.0 228.5 L -96.4 227.4 L -100.7 226.2 '
    'L -104.9 224.9 L -109.1 223.5 L -113.3 221.9 L -117.3 220.3 '
    'L -121.4 218.6 L -125.3 216.8 L -129.1 214.8 L -132.9 212.8 '
    'L -136.6 210.7 L -140.2 208.5 L -143.7 206.2 L -147.1 203.8 '
    'L -150.4 201.3 L -153.7 198.6 L -157.0 195.9 L -160.2 193.0 '
    'L -163.4 190.0 L -166.5 186.9 L -169.7 183.7 L -172.8 180.3 '
    'L -175.7 176.8 L -178.6 173.2 L -181.2 169.5 L -183.5 165.7 '
    'L -185.5 161.9 L -187.1 158.0 L -188.2 154.1 L -188.9 150.1 '
    'L -189.0 146.1 L -188.5 142.1 L -187.7 138.1 L -186.4 134.1 '
    'L -184.7 130.2 L -182.6 126.4 L -180.3 122.7 L -177.7 119.2 '
    'L -174.9 115.8 L -171.9 112.6 L -168.7 109.5 L -165.5 106.7 '
    'L -162.2 104.0 L -158.7 101.5 L -155.2 99.0 L -151.7 96.6 L -148.1 94.2 '
    'L -144.4 91.8 L -140.8 89.4 L -137.1 86.8 L -133.4 84.2 L -129.7 81.6 '
    'L -126.0 78.9 L -122.3 76.3 L -118.6 73.8 L -114.9 71.4 L -111.1 69.3 '
    'L -107.3 67.5 L -103.4 66.0 L -99.5 64.9 L -95.6 64.3 L -91.6 64.1 '
    'L -87.7 64.3 L -83.7 64.9 L -79.7 65.9 L -75.8 67.3 L -71.9 69.0 '
    'L -68.2 71.1 L -64.4 73.6 L -60.8 76.4 L -57.4 79.4 L -54.0 82.8 '
    'L -50.7 86.2 L -47.4 89.7 L -44.1 93.1 L -40.9 96.3 L -37.6 99.3 '
    'L -34.2 101.8 L -30.8 103.9 L -27.2 105.5 L -23.5 106.4 L -19.8 106.7 '
    'L -15.9 106.5 L -12.0 105.9 L -8.0 104.8 L -4.1 103.3 L -0.1 101.6 '
    'L 3.7 99.5 L 7.5 97.3 L 11.2 94.9 L 14.8 92.3 L 18.3 89.7 L 21.6 87.0 '
    'L 24.9 84.1 L 28.1 81.3 L 31.2 78.3 L 34.3 75.3 L 37.3 72.2 L 40.3 69.1 '
    'L 43.2 66.0 L 46.2 62.9 L 49.1 59.7 L 52.1 56.5 L 55.0 53.4 L 58.0 50.2 '
    'L 61.1 47.1 L 64.2 44.0 L 67.4 40.9 L 70.7 37.9 L 74.0 34.9 L 77.4 32.0 '
    'L 80.9 29.0 L 84.2 26.1 L 87.5 23.1 L 90.7 20.0 L 93.7 16.9 L 96.5 13.6 '
    'L 99.0 10.2 L 101.3 6.6 L 103.2 2.9 L 104.8 -0.9 L 106.0 -4.8 '
    'L 106.8 -8.8 L 107.2 -12.8 L 107.1 -16.8 L 106.6 -20.8 L 105.6 -24.6 '
    'L 104.1 -28.4 L 102.0 -32.0 L 99.5 -35.5 L 96.5 -38.8 L 93.3 -42.0 '
    'L 89.9 -45.2 L 86.5 -48.4 L 83.2 -51.6 L 80.1 -54.9 L 77.3 -58.3 '
    'L 74.9 -61.8 L 73.2 -65.4 L 72.0 -69.3 L 71.4 -73.2 L 71.3 -77.2 '
    'L 71.7 -81.2 L 72.6 -85.2 L 74.0 -89.2 L 75.9 -93.2 L 78.0 -97.0 '
    'L 80.3 -100.8 L 82.8 -104.5 L 85.4 -108.1 L 88.1 -111.5 L 90.8 -114.9 '
    'L 93.5 -118.3 L 96.3 -121.6 L 99.1 -125.0 L 101.8 -128.3 L 104.5 -131.7 '
    'L 107.2 -135.2 L 109.9 -138.8 L 112.5 -142.4 L 115.1 -146.1 '
    'L 117.7 -149.7 L 120.4 -153.2 L 123.2 -156.6 L 126.1 -159.8 '
    'L 129.1 -162.8 L 132.4 -165.5 L 135.8 -167.9 L 139.5 -169.8 '
    'L 143.4 -171.4 L 147.4 -172.7 L 151.6 -173.6 L 155.8 -174.1 '
    'L 160.1 -174.3 L 164.4 -174.1 L 168.7 -173.6 L 173.0 -172.8 '
    'L 177.1 -171.6 L 181.1 -170.2 L 184.9 -168.4 L 188.5 -166.4 '
    'L 192.0 -164.0 L 195.4 -161.5 L 198.6 -158.7 L 201.7 -155.8 '
    'L 204.7 -152.6 L 207.5 -149.4 L 210.3 -146.0 L 213.1 -142.5 '
    'L 215.7 -139.0 L 218.2 -135.3 L 220.7 -131.6 L 223.1 -127.9 '
    'L 225.4 -124.0 L 227.5 -120.1 L 229.6 -116.2 L 231.6 -112.2 '
    'L 233.4 -108.1 L 235.1 -104.1 L 236.7 -99.9 L 238.1 -95.8 L 239.4 -91.6 '
    'L 240.5 -87.4 L 241.5 -83.2 L 242.4 -78.9 L 243.1 -74.7 L 243.6 -70.5 '
    'L 243.9 -66.2 L 244.0 -62.0 L 244.0 -57.7 L 243.8 -53.5 L 243.4 -49.3 '
    'L 242.8 -45.1 L 242.1 -41.0 L 241.2 -36.8 L 240.2 -32.7 L 239.0 -28.6 '
    'L 237.7 -24.5 L 236.3 -20.4 L 234.7 -16.4 L 233.0 -12.3 L 231.2 -8.4 '
    'L 229.4 -4.4 L 227.4 -0.5 L 225.4 3.4 L 223.2 7.3 L 221.1 11.1 '
    'L 218.8 14.9 L 216.5 18.7 L 214.2 22.4 L 211.8 26.1 L 209.3 29.8 '
    'L 206.9 33.4 L 204.4 36.9 L 201.9 40.5 L 199.3 44.0 L 196.8 47.4 '
    'L 194.2 50.9 L 191.5 54.3 L 188.9 57.7 L 186.2 61.0 L 183.5 64.3 '
    'L 180.7 67.6 L 178.0 70.9 L 175.2 74.1 L 172.4 77.3 L 169.5 80.5 '
    'L 166.7 83.7 L 163.8 86.9 L 160.9 90.0 L 157.9 93.1 L 155.0 96.2 '
    'L 152.0 99.3 L 149.0 102.4 L 146.0 105.5 L 143.0 108.5 L 140.0 111.5 '
    'L 136.9 114.6 L 133.8 117.6 L 130.7 120.6 L 127.6 123.6 L 124.5 126.6 '
    'L 121.4 129.6 L 118.2 132.6 L 115.1 135.6 L 111.9 138.6 L 108.7 141.6 '
    'L 105.5 144.6 L 102.3 147.6 L 99.1 150.6 L 95.8 153.7 L 92.6 156.7 '
    'L 89.4 159.7 L 86.1 162.6 L 82.8 165.6 L 79.5 168.6 L 76.2 171.5 '
    'L 72.9 174.4 L 69.5 177.3 L 66.1 180.1 L 62.7 182.9 L 59.3 185.7 '
    'L 55.9 188.4 L 52.5 191.1 L 49.0 193.7 L 45.5 196.3 L 41.9 198.8 '
    'L 38.4 201.3 L 34.8 203.7 L 31.2 206.0 L 27.6 208.3 L 23.9 210.4 '
    'L 20.2 212.5 L 16.5 214.6 L 12.7 216.5 L 8.9 218.4 L 5.1 220.1 '
    'L 1.3 221.8 L -2.6 223.3 L -6.6 224.8 L -10.5 226.1 L -14.5 227.4 '
    'L -18.6 228.5 L -22.7 229.5 L -26.8 230.4 L -31.0 231.2 L -35.2 231.8 Z'
)


def handle_geom():
    a = math.radians(HANDLE_ANGLE)
    u = (math.cos(a), math.sin(a))
    n = (-u[1], u[0])
    h = HANDLE_W / 2
    s = (u[0] * HANDLE_FROM, u[1] * HANDLE_FROM)
    e = (u[0] * (HANDLE_TIP - h), u[1] * (HANDLE_TIP - h))
    t = (u[0] * HANDLE_TIP, u[1] * HANDLE_TIP)
    p = lambda q, k: f'{q[0] + n[0] * k:.1f} {q[1] + n[1] * k:.1f}'
    path = (f'M {p(s, h)} L {p(e, h)} A {h} {h} 0 0 0 {p(e, -h)} '
            f'L {p(s, -h)} Z')
    return path, s, t


def waves_path():
    d = []
    for cx, cy, r, a0, a1 in WAVES:
        b0, b1 = math.radians(a0), math.radians(a1)
        d.append(f'M {cx + r * math.cos(b0):.1f} {cy + r * math.sin(b0):.1f} '
                 f'A {r} {r} 0 0 1 {cx + r * math.cos(b1):.1f} {cy + r * math.sin(b1):.1f}')
    return ' '.join(d)


DEFS = '''
  <linearGradient id="ring" x1="0.15" y1="0.12" x2="0.85" y2="0.9">
    <stop offset="0" stop-color="#2E92FD"/>
    <stop offset="0.3" stop-color="#1370F9"/>
    <stop offset="0.62" stop-color="#0349D8"/>
    <stop offset="1" stop-color="#01309F"/>
  </linearGradient>
  <linearGradient id="line" x1="0" y1="1" x2="1" y2="0">
    <stop offset="0" stop-color="#01175E"/>
    <stop offset="1" stop-color="#012A8D"/>
  </linearGradient>
  <radialGradient id="lens" cx="0.36" cy="0.3" r="0.85">
    <stop offset="0" stop-color="#FFFFFF"/>
    <stop offset="0.55" stop-color="#FBFCFF"/>
    <stop offset="1" stop-color="#CBE2FD"/>
  </radialGradient>
  <linearGradient id="ink" x1="0.2" y1="0" x2="0.6" y2="1">
    <stop offset="0" stop-color="#1667FF"/>
    <stop offset="1" stop-color="#0034BE"/>
  </linearGradient>
'''


def handle_gradient(s, t):
    return (f'<linearGradient id="hnd" gradientUnits="userSpaceOnUse" '
            f'x1="{s[0] + (t[0] - s[0]) * 0.08:.1f}" y1="{s[1] + (t[1] - s[1]) * 0.08:.1f}" '
            f'x2="{t[0]:.1f}" y2="{t[1]:.1f}">'
            '<stop offset="0" stop-color="#B4D9FE"/>'
            '<stop offset="0.45" stop-color="#2A7DFD"/>'
            '<stop offset="1" stop-color="#0044DE"/></linearGradient>')


def layers():
    """SVG qatlamlari: halqa, dasta, linza, go'shak va soyalar uchun shakllar."""
    hpath, s, t = handle_geom()
    defs = f'<defs>{DEFS}{handle_gradient(s, t)}</defs>'
    ring = (f'{defs}<circle r="{RING_R}" fill="url(#ring)"/>'
            f'<circle r="{LINE_R}" fill="none" stroke="url(#line)" stroke-width="{LINE_W}"/>')
    handle = f'{defs}<path d="{hpath}" fill="url(#hnd)"/>'
    lens = f'{defs}<circle r="{LENS_R}" fill="url(#lens)"/>'
    ink = (f'{defs}<path d="{waves_path()}" fill="none" stroke="url(#ink)" '
           f'stroke-width="{WAVE_W}" stroke-linecap="round"/>'
           f'<path d="{HANDSET}" fill="url(#ink)"/>')
    # soya uchun shakllar (rang muhim emas — faqat alfa)
    ring_shape = f'<circle r="{RING_R}" fill="#000"/><path d="{hpath}" fill="#000"/>'
    handle_shape = f'<path d="{hpath}" fill="#000"/>'
    ink_shape = (f'<path d="{waves_path()}" fill="none" stroke="#000" '
                 f'stroke-width="{WAVE_W}" stroke-linecap="round"/>'
                 f'<path d="{HANDSET}" fill="#000"/>')
    return ring, handle, lens, ink, ring_shape, handle_shape, ink_shape


def render(body, ppu, anchor, at, size=BIG):
    ax, ay = anchor
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
           f'viewBox="0 0 {size} {size}"><g transform="translate({at[0]} {at[1]}) '
           f'scale({ppu}) translate({-ax} {-ay})">{body}</g></svg>')
    png = cairosvg.svg2png(bytestring=svg.encode('utf-8'))
    return Image.open(io.BytesIO(png)).convert('RGBA')


def shadow(shape, color, opacity, blur, dx, dy):
    a = shape.getchannel('A').point(lambda v: int(v * opacity))
    sh = Image.new('RGBA', shape.size, color + (0,))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new('RGBA', shape.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (int(dx), int(dy)))
    return out


def glyph(ppu, anchor, at, size=BIG):
    """Butun belgi (soyalari bilan) shaffof fonda."""
    ring, handle, lens, ink, ring_s, handle_s, ink_s = layers()
    k = ppu  # 1 birlik → k piksel
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    r = lambda b: render(b, ppu, anchor, at, size)

    rs = r(ring_s)
    out.alpha_composite(shadow(rs, (0, 6, 40), 0.75, 34 * k, 14 * k, 26 * k))
    out.alpha_composite(r(ring))
    out.alpha_composite(shadow(r(handle_s), (0, 10, 60), 0.6, 10 * k, 6 * k, 10 * k))
    out.alpha_composite(r(handle))
    out.alpha_composite(r(lens))
    out.alpha_composite(shadow(r(ink_s), (0, 30, 120), 0.18, 6 * k, 0, 5 * k))
    out.alpha_composite(r(ink))
    return out


def background(size=BIG):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1000 1000">
  <defs>
    <linearGradient id="bg" x1="0.05" y1="0" x2="0.75" y2="1">
      <stop offset="0" stop-color="#0B4DC9"/>
      <stop offset="0.45" stop-color="#022A8E"/>
      <stop offset="1" stop-color="#011660"/>
    </linearGradient>
  </defs>
  <rect width="1000" height="1000" fill="url(#bg)"/>
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
    bg = background()

    # ── iOS va oddiy Android ikonkasi: namunadagi joylashuv ──
    ppu = BIG / REF_CANVAS
    at = (REF_CENTER[0] * ppu, REF_CENTER[1] * ppu)
    icon = bg.copy()
    icon.alpha_composite(glyph(ppu, (0, 0), at))
    icon = down(icon).convert('RGB')
    icon.save(os.path.join(ASSETS, 'icon_ios.png'), optimize=True)
    icon.save(os.path.join(ASSETS, 'icon.png'), optimize=True)

    # ── Android adaptiv ikonkasi ──
    # Lupa markazi tuval markazida. (Avval markaz dasta tomonga surilgan
    # edi — Android'da lupa yuqori-chap burchakka siljib ko'rinardi.)
    ppu_a = BIG * ANDROID_TIP / HANDLE_TIP
    fg = glyph(ppu_a, (0, 0), (BIG / 2, BIG / 2))
    down(fg).save(os.path.join(ASSETS, 'icon_android_fg.png'), optimize=True)
    down(bg).convert('RGB').save(os.path.join(ASSETS, 'icon_android_bg.png'),
                                 optimize=True)

    # ── Yuklash ekrani: bir xil rangli fon (#05193F), belgi + nom ──
    splash = Image.new('RGBA', (BIG, BIG), SPLASH_BG + (255,))
    ppu_s = BIG * 0.20 / RING_R
    gc = (BIG / 2, BIG * 0.36)
    halo = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    hr = BIG * 0.22
    ImageDraw.Draw(halo).ellipse((gc[0] - hr, gc[1] - hr, gc[0] + hr, gc[1] + hr),
                                 fill=(26, 123, 252, 55))
    splash.alpha_composite(halo.filter(ImageFilter.GaussianBlur(int(BIG * 0.07))))
    splash.alpha_composite(glyph(ppu_s, (0, 0), gc))

    save_splash(splash)

    print('Tayyor (halqa):', ', '.join(sorted(
        f for f in os.listdir(ASSETS) if f.endswith('.png'))))


def save_splash(splash):
    """Nom va izohni yozib, splash_logo.png sifatida saqlaydi."""
    d = ImageDraw.Draw(splash)
    title = font(['/usr/share/fonts/opentype/inter/Inter-Bold.otf',
                  'Inter-Bold.ttf', 'DejaVuSans-Bold.ttf'], 104 * SS)
    sub = font(['/usr/share/fonts/opentype/inter/Inter-Medium.otf',
                'Inter-Medium.ttf', 'DejaVuSans.ttf'], 44 * SS)
    d.text((BIG / 2, 700 * SS), 'Getcontact', font=title,
           fill=(255, 255, 255), anchor='mm')
    d.text((BIG / 2, 784 * SS), "Ma'lumotlar qidiruvi", font=sub,
           fill=(140, 184, 242), anchor='mm')
    down(splash).convert('RGB').save(os.path.join(ASSETS, 'splash_logo.png'),
                                     optimize=True)


def main_romb():
    """Asl dizayn: yumaloq romb, tekis ranglar, oq fon."""
    import icon_romb as R

    os.makedirs(ASSETS, exist_ok=True)
    white = Image.new('RGBA', (BIG, BIG), (255, 255, 255, 255))
    body = R.body()
    silhouette = body.replace('fill="#FFFFFF"', 'fill="#000"')

    def romb(ppu, at, size=BIG, soft=True):
        out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        if soft:
            sil = render(silhouette, ppu, (0, 0), at, size)
            out.alpha_composite(shadow(sil, (10, 40, 110), 0.28,
                                       22 * ppu, 0, 16 * ppu))
        out.alpha_composite(render(body, ppu, (0, 0), at, size))
        return out

    # ── iOS va oddiy Android ikonkasi ──
    # Belgi chegaralari markazga olinadi va tuvalning 82% ini egallaydi.
    l, t, r, b = R.extents()
    ppu = BIG * 0.82 / max(r - l, b - t)
    at = (BIG / 2 - (l + r) / 2 * ppu, BIG / 2 - (t + b) / 2 * ppu)
    icon = white.copy()
    icon.alpha_composite(romb(ppu, at))
    icon = down(icon).convert('RGB')
    icon.save(os.path.join(ASSETS, 'icon_ios.png'), optimize=True)
    icon.save(os.path.join(ASSETS, 'icon.png'), optimize=True)

    # ── Android adaptiv: lupa markazi tuval markazida ──
    ppu_a = BIG * ANDROID_TIP / R.HANDLE_TIP
    down(romb(ppu_a, (BIG / 2, BIG / 2))).save(
        os.path.join(ASSETS, 'icon_android_fg.png'), optimize=True)
    down(white).convert('RGB').save(
        os.path.join(ASSETS, 'icon_android_bg.png'), optimize=True)

    # ── Yuklash ekrani: ilova foni (#05193F), oq yorug'lik ustida romb ──
    splash = Image.new('RGBA', (BIG, BIG), SPLASH_BG + (255,))
    gc = (BIG / 2, BIG * 0.36)
    halo = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    hr = BIG * 0.22
    ImageDraw.Draw(halo).ellipse((gc[0] - hr, gc[1] - hr, gc[0] + hr, gc[1] + hr),
                                 fill=(35, 95, 200, 70))
    splash.alpha_composite(halo.filter(ImageFilter.GaussianBlur(int(BIG * 0.07))))
    splash.alpha_composite(romb(BIG * 0.20 / R.CORNER, gc, soft=False))
    save_splash(splash)

    print('Tayyor (romb):', ', '.join(sorted(
        f for f in os.listdir(ASSETS) if f.endswith('.png'))))


if __name__ == '__main__':
    style = (sys.argv[1] if len(sys.argv) > 1 else 'halqa').lower()
    if style == 'romb':
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        sys.exit(main_romb())
    sys.exit(main())
