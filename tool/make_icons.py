#!/usr/bin/env python3
"""Ilova ikonkalari va yuklash ekrani rasmini vektordan yasaydi.

Ishlatish (loyiha ildizidan):
    pip install cairosvg pillow
    python3 tool/make_icons.py

Natija (assets/):
    icon_ios.png        1024x1024, RGB — iOS ikonkasi (shaffofliksiz)
    icon.png            1024x1024, RGB — Android oddiy ikonkasi
    icon_android_fg.png 1024x1024, RGBA — Android adaptiv ikonkasi (old qatlam)
    icon_android_bg.png 1024x1024, RGB — Android adaptiv ikonkasi (fon)
    splash_logo.png     1024x1024, RGB — yuklash ekrani (fon #05193F)

Belgi: lupa ichida telefon go'shagi. Go'shak shakli Material Icons
("call", rounded) dan olingan — Apache 2.0 litsenziyasi.
"""

import io
import os
import sys

import cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'assets')

SPLASH_BG = (0x05, 0x19, 0x3F)  # pubspec.yaml: flutter_native_splash.color

# Material Icons "call" (rounded), 24x24
HANDSET = (
    'M19.23 15.26l-2.54-.29c-.61-.07-1.21.14-1.64.57l-1.84 1.84'
    'c-2.83-1.44-5.15-3.75-6.59-6.59l1.85-1.85c.43-.43.64-1.03.57-1.64'
    'l-.29-2.52c-.12-1.01-.97-1.77-1.99-1.77H5.03c-1.13 0-2.07.94-2 2.07'
    '.53 8.54 7.36 15.36 15.89 15.89 1.13.07 2.07-.87 2.07-2v-1.73'
    'c.01-1.01-.75-1.86-1.76-1.98z'
)


def glyph_svg(cx=430, cy=430):
    """Lupa + go'shak, shaffof fonda. (cx, cy) — linza markazi."""
    r_ring = 232      # halqa chizig'ining o'rtasi
    w_ring = 92       # halqa qalinligi
    r_lens = r_ring - w_ring / 2

    # Dasta — 45° burchakda pastga-o'ngga
    h0 = (cx + 185, cy + 185)
    h1 = (cx + 405, cy + 405)

    # Go'shak: 24 birlik → ~240 px, linza markazida
    s = 10.6
    tx, ty = cx - 12 * s, cy - 12 * s

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <defs>
    <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#9FD0FF"/>
      <stop offset="0.45" stop-color="#3D8BFF"/>
      <stop offset="1" stop-color="#1A4FC2"/>
    </linearGradient>
    <linearGradient id="handle" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2F74E8"/>
      <stop offset="1" stop-color="#163F9E"/>
    </linearGradient>
    <radialGradient id="lens" cx="0.38" cy="0.34" r="0.75">
      <stop offset="0" stop-color="#174A9E"/>
      <stop offset="0.6" stop-color="#0A2659"/>
      <stop offset="1" stop-color="#061A42"/>
    </radialGradient>
    <linearGradient id="phone" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#BFDBFF"/>
    </linearGradient>
  </defs>

  <!-- dasta (halqa ostida) -->
  <line x1="{h0[0]}" y1="{h0[1]}" x2="{h1[0]}" y2="{h1[1]}"
        stroke="url(#handle)" stroke-width="104" stroke-linecap="round"/>
  <!-- dasta ustidagi yorug' chiziq -->
  <line x1="{h0[0] + 40}" y1="{h0[1] + 10}" x2="{h1[0] - 14}" y2="{h1[1] - 44}"
        stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="16" stroke-linecap="round"/>

  <!-- linza shishasi -->
  <circle cx="{cx}" cy="{cy}" r="{r_lens}" fill="url(#lens)"/>

  <!-- halqa -->
  <circle cx="{cx}" cy="{cy}" r="{r_ring}" fill="none"
          stroke="url(#ring)" stroke-width="{w_ring}"/>
  <!-- halqaning ichki chekkasi (chuqurlik) -->
  <circle cx="{cx}" cy="{cy}" r="{r_lens + 3}" fill="none"
          stroke="#031030" stroke-opacity="0.55" stroke-width="6"/>

  <!-- shishadagi aks -->
  <path d="M {cx - 150} {cy - 30} A 152 152 0 0 1 {cx - 30} {cy - 150}"
        fill="none" stroke="#FFFFFF" stroke-opacity="0.35"
        stroke-width="20" stroke-linecap="round"/>

  <!-- go'shak -->
  <g transform="translate({tx} {ty}) scale({s})">
    <path d="{HANDSET}" fill="url(#phone)"/>
  </g>
</svg>'''


BG_SVG = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0E3D8F"/>
      <stop offset="0.55" stop-color="#06204F"/>
      <stop offset="1" stop-color="#030E28"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.44" cy="0.44" r="0.46">
      <stop offset="0" stop-color="#3D8BFF" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#3D8BFF" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{SIZE}" height="{SIZE}" fill="url(#bg)"/>
  <rect width="{SIZE}" height="{SIZE}" fill="url(#glow)"/>
</svg>'''


def render(svg):
    png = cairosvg.svg2png(bytestring=svg.encode('utf-8'),
                           output_width=SIZE, output_height=SIZE)
    return Image.open(io.BytesIO(png)).convert('RGBA')


def with_shadow(glyph, offset=18, blur=26, opacity=0.5):
    """Belgi ostiga yumshoq soya qo'shadi (cairosvg blur qila olmaydi)."""
    alpha = glyph.getchannel('A')
    shadow = Image.new('RGBA', glyph.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda a: int(a * opacity)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas = Image.new('RGBA', glyph.size, (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (0, offset))
    canvas.alpha_composite(glyph)
    return canvas


def scaled(img, factor, center_shift=(0, 0)):
    """Rasmni markaz bo'yicha kichraytirib, shu o'lchamdagi tuvalga qo'yadi."""
    w = int(SIZE * factor)
    small = img.resize((w, w), Image.LANCZOS)
    out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    pos = ((SIZE - w) // 2 + center_shift[0], (SIZE - w) // 2 + center_shift[1])
    out.alpha_composite(small, pos)
    return out


def font(names, size):
    for n in names:
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    os.makedirs(ASSETS, exist_ok=True)

    bg = render(BG_SVG)
    glyph = with_shadow(render(glyph_svg()))

    # ── iOS va oddiy Android ikonkasi: to'liq kvadrat, shaffofliksiz ──
    icon = bg.copy()
    icon.alpha_composite(glyph)
    icon = icon.convert('RGB')
    icon.save(os.path.join(ASSETS, 'icon_ios.png'), optimize=True)
    icon.save(os.path.join(ASSETS, 'icon.png'), optimize=True)

    # ── Android adaptiv ikonkasi ──
    # Ko'rinadigan xavfsiz doira — tuvalning ~61% i. Belgining eng uzoq
    # nuqtasi (dasta uchi) shu doiradan chiqmasligi uchun 0.60 ga kichraytiramiz.
    fg = scaled(glyph, 0.60)
    fg.save(os.path.join(ASSETS, 'icon_android_fg.png'), optimize=True)
    bg.convert('RGB').save(os.path.join(ASSETS, 'icon_android_bg.png'), optimize=True)

    # ── Yuklash ekrani: bir xil rangli fon (#05193F), belgi + nom ──
    splash = Image.new('RGBA', (SIZE, SIZE), SPLASH_BG + (255,))
    halo = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((282, 92, 742, 552), fill=(61, 139, 255, 70))
    splash.alpha_composite(halo.filter(ImageFilter.GaussianBlur(70)))
    splash.alpha_composite(scaled(glyph, 0.46, center_shift=(0, -190)))

    d = ImageDraw.Draw(splash)
    title = font(['Inter-Bold.ttf', 'Inter Bold', '/usr/share/fonts/opentype/inter/Inter-Bold.otf',
                  'DejaVuSans-Bold.ttf'], 104)
    sub = font(['Inter-Medium.ttf', 'Inter Medium', '/usr/share/fonts/opentype/inter/Inter-Medium.otf',
                'DejaVuSans.ttf'], 44)
    d.text((SIZE / 2, 668), 'Getcontact', font=title, fill=(255, 255, 255), anchor='mm')
    d.text((SIZE / 2, 752), "Ma'lumotlar qidiruvi", font=sub, fill=(140, 184, 242), anchor='mm')
    splash.convert('RGB').save(os.path.join(ASSETS, 'splash_logo.png'), optimize=True)

    print('Tayyor:', ', '.join(sorted(f for f in os.listdir(ASSETS) if f.endswith('.png'))))


if __name__ == '__main__':
    sys.exit(main())
