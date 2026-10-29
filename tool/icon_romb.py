"""«Romb» uslubidagi belgi: asl dizayn — yumaloq romb ichida lupa.

make_icons.py tomonidan ishlatiladi:  python3 tool/make_icons.py romb

Birlik: (0,0) — linza markazi, linza radiusi 309. Shakl foydalanuvchi
bergan asl rasmdan o'lchab olingan; ranglar tekis (asl rasmdagidek).
"""

import math

# Go'shak — asl rasmdan ko'chirilgan kontur
HANDSET = (
    'M -53.4 209.7 L -58.2 210.2 L -63.0 210.5 L -67.9 210.6 L -72.8 210.5 '
    'L -77.7 210.1 L -82.5 209.5 L -87.3 208.6 L -92.0 207.4 L -96.6 206.0 '
    'L -101.1 204.4 L -105.5 202.4 L -109.8 200.3 L -114.0 197.9 '
    'L -118.0 195.3 L -122.0 192.5 L -125.9 189.6 L -129.8 186.6 '
    'L -133.6 183.6 L -137.3 180.4 L -141.0 177.2 L -144.6 173.9 '
    'L -148.2 170.5 L -151.6 167.0 L -155.0 163.4 L -158.2 159.7 '
    'L -161.3 155.7 L -164.2 151.7 L -166.7 147.5 L -168.5 143.1 '
    'L -169.4 138.6 L -169.4 134.0 L -168.6 129.3 L -167.1 124.6 '
    'L -165.2 120.1 L -162.9 115.7 L -160.5 111.6 L -157.8 107.6 '
    'L -154.9 103.8 L -151.8 100.2 L -148.5 96.8 L -145.1 93.4 L -141.6 90.2 '
    'L -137.9 87.1 L -134.0 84.1 L -130.1 81.2 L -126.1 78.3 L -122.0 75.5 '
    'L -117.8 72.7 L -113.6 69.9 L -109.3 67.2 L -105.0 64.5 L -100.7 61.9 '
    'L -96.4 59.6 L -92.0 57.7 L -87.7 56.2 L -83.4 55.2 L -79.1 55.0 '
    'L -74.8 55.5 L -70.6 57.0 L -66.5 59.3 L -62.4 62.2 L -58.7 65.7 '
    'L -55.2 69.4 L -51.9 73.3 L -48.7 77.2 L -45.4 81.1 L -42.0 84.6 '
    'L -38.2 87.8 L -34.2 90.5 L -30.0 92.5 L -25.5 93.8 L -20.9 94.2 '
    'L -16.2 93.9 L -11.6 93.0 L -7.1 91.4 L -2.9 89.3 L 1.1 86.8 L 5.0 83.8 '
    'L 8.7 80.5 L 12.3 77.1 L 15.8 73.4 L 19.2 69.8 L 22.6 66.1 L 26.0 62.5 '
    'L 29.4 58.9 L 32.8 55.4 L 36.2 51.9 L 39.5 48.4 L 42.9 44.9 L 46.4 41.5 '
    'L 49.8 38.1 L 53.2 34.7 L 56.7 31.3 L 60.2 27.9 L 63.8 24.6 L 67.3 21.2 '
    'L 70.9 17.8 L 74.6 14.4 L 78.3 10.9 L 81.9 7.4 L 85.4 3.9 L 88.6 0.2 '
    'L 91.5 -3.7 L 94.1 -7.7 L 96.1 -12.0 L 97.6 -16.5 L 98.4 -21.2 '
    'L 98.6 -25.9 L 98.2 -30.7 L 97.0 -35.2 L 95.0 -39.5 L 92.4 -43.4 '
    'L 89.3 -47.1 L 85.7 -50.5 L 81.9 -53.9 L 78.0 -57.2 L 74.1 -60.5 '
    'L 70.4 -63.8 L 67.0 -67.2 L 64.1 -70.8 L 61.8 -74.7 L 60.3 -78.7 '
    'L 59.6 -83.1 L 59.8 -87.8 L 60.7 -92.6 L 62.3 -97.4 L 64.3 -102.1 '
    'L 66.6 -106.5 L 69.2 -110.8 L 71.9 -114.9 L 74.7 -118.8 L 77.5 -122.8 '
    'L 80.3 -126.7 L 83.2 -130.5 L 86.1 -134.3 L 89.0 -138.1 L 92.0 -141.9 '
    'L 95.1 -145.6 L 98.3 -149.3 L 101.6 -153.0 L 105.0 -156.5 '
    'L 108.6 -159.9 L 112.4 -163.1 L 116.4 -166.0 L 120.5 -168.5 '
    'L 124.9 -170.5 L 129.5 -172.1 L 134.3 -173.1 L 139.2 -173.5 '
    'L 144.1 -173.3 L 148.7 -172.4 L 153.1 -170.7 L 157.2 -168.4 '
    'L 161.1 -165.6 L 164.8 -162.5 L 168.4 -159.2 L 172.1 -155.9 '
    'L 175.7 -152.6 L 179.3 -149.2 L 182.8 -145.7 L 186.2 -142.1 '
    'L 189.5 -138.5 L 192.6 -134.7 L 195.6 -130.8 L 198.3 -126.7 '
    'L 200.8 -122.6 L 203.2 -118.3 L 205.3 -113.9 L 207.2 -109.5 '
    'L 208.9 -105.0 L 210.5 -100.4 L 211.8 -95.7 L 212.9 -91.1 L 213.7 -86.3 '
    'L 214.4 -81.6 L 214.8 -76.8 L 215.1 -72.0 L 215.1 -67.2 L 214.8 -62.5 '
    'L 214.4 -57.7 L 213.7 -53.0 L 212.8 -48.4 L 211.6 -43.7 L 210.2 -39.2 '
    'L 208.7 -34.6 L 207.0 -30.1 L 205.0 -25.7 L 202.9 -21.3 L 200.7 -16.9 '
    'L 198.3 -12.7 L 195.8 -8.4 L 193.2 -4.2 L 190.5 -0.1 L 187.7 4.0 '
    'L 184.8 8.0 L 181.8 11.9 L 178.7 15.8 L 175.7 19.6 L 172.5 23.4 '
    'L 169.4 27.1 L 166.2 30.8 L 162.9 34.4 L 159.6 38.0 L 156.3 41.5 '
    'L 153.0 45.0 L 149.7 48.5 L 146.3 52.0 L 142.9 55.4 L 139.5 58.9 '
    'L 136.1 62.3 L 132.6 65.7 L 129.2 69.2 L 125.7 72.6 L 122.2 76.0 '
    'L 118.8 79.5 L 115.3 83.0 L 111.8 86.4 L 108.3 89.9 L 104.8 93.4 '
    'L 101.3 96.9 L 97.9 100.4 L 94.4 103.9 L 90.9 107.4 L 87.4 110.9 '
    'L 83.9 114.3 L 80.4 117.8 L 77.0 121.3 L 73.5 124.8 L 70.0 128.3 '
    'L 66.6 131.7 L 63.1 135.2 L 59.7 138.6 L 56.2 142.0 L 52.7 145.4 '
    'L 49.2 148.8 L 45.7 152.1 L 42.1 155.4 L 38.5 158.7 L 34.9 161.9 '
    'L 31.2 165.1 L 27.5 168.3 L 23.8 171.3 L 20.0 174.4 L 16.1 177.4 '
    'L 12.2 180.3 L 8.2 183.1 L 4.2 185.9 L 0.1 188.5 L -4.0 191.1 '
    'L -8.2 193.6 L -12.5 195.9 L -16.8 198.1 L -21.2 200.1 L -25.6 202.0 '
    'L -30.1 203.8 L -34.6 205.3 L -39.2 206.7 L -43.9 207.9 L -48.6 208.9 Z'
)

SHAPE_A = 443           # romb tomonigacha masofa (diagonal bo'yicha)
SHAPE_N = 2.5           # superellips darajasi
LENS_R = 309
SHADOW = (-4, 36)       # linza soyasi (asosan pastga)

HANDLE_W = 102
NECK_END = 439          # oq bo'yin romb chetida tugaydi
HANDLE_START = 449      # tirqishdan keyin dasta
HANDLE_TIP = 617        # dasta uchi — belgining eng uzoq nuqtasi

WAVES_C = (15, 17.5)
WAVES_R = (116, 168.5, 220)
WAVE_W = 22

BLUE = '#235FC8'
SHADE = '#1D50AE'

# Romb uchi (o'qlar bo'yicha) — iOS joylashuvi uchun
CORNER = SHAPE_A * 2 ** (0.5 - 1 / SHAPE_N)


def _diag(d):
    k = d / math.sqrt(2)
    return round(k, 2), round(k, 2)


def shape_path(steps=720):
    """45° ga burilgan superellips."""
    pts = []
    cr = sr = math.cos(math.radians(45))
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        x = SHAPE_A * math.copysign(abs(c) ** (2 / SHAPE_N), c)
        y = SHAPE_A * math.copysign(abs(s) ** (2 / SHAPE_N), s)
        pts.append(f'{x * cr - y * sr:.2f} {x * sr + y * cr:.2f}')
    return 'M ' + ' L '.join(pts) + ' Z'


def _handle_path():
    h = HANDLE_W / 2
    k = h / math.sqrt(2)
    sx, sy = _diag(HANDLE_START)
    ex, ey = _diag(HANDLE_TIP - h)
    return (f'M {sx + k:.1f} {sy - k:.1f} L {ex + k:.1f} {ey - k:.1f} '
            f'A {h} {h} 0 0 1 {ex - k:.1f} {ey + k:.1f} L {sx - k:.1f} {sy + k:.1f} Z')


def _waves():
    cx, cy = WAVES_C
    d = []
    for r in WAVES_R:
        a0, a1 = math.radians(180), math.radians(270)
        d.append(f'M {cx + r * math.cos(a0):.1f} {cy + r * math.sin(a0):.1f} '
                 f'A {r} {r} 0 0 1 {cx + r * math.cos(a1):.1f} {cy + r * math.sin(a1):.1f}')
    return ' '.join(d)


def body():
    shape = shape_path()
    nx, ny = _diag(NECK_END)
    sdx, sdy = SHADOW
    return f'''
  <defs><clipPath id="romb"><path d="{shape}"/></clipPath></defs>
  <path d="{shape}" fill="{BLUE}"/>
  <g clip-path="url(#romb)">
    <g transform="translate({sdx} {sdy})">
      <circle r="{LENS_R}" fill="{SHADE}"/>
      <line x1="0" y1="0" x2="{nx}" y2="{ny}" stroke="{SHADE}" stroke-width="{HANDLE_W}"/>
    </g>
    <line x1="0" y1="0" x2="{nx}" y2="{ny}" stroke="#FFFFFF" stroke-width="{HANDLE_W}"/>
  </g>
  <circle r="{LENS_R}" fill="#FFFFFF"/>
  <path d="{_handle_path()}" fill="{BLUE}"/>
  <path d="{_waves()}" fill="none" stroke="{BLUE}" stroke-width="{WAVE_W}" stroke-linecap="round"/>
  <path d="{HANDSET}" fill="{BLUE}"/>'''


def extents():
    """Belgining chegaralari (birlikda): chap, yuqori, o'ng, past."""
    tip = _diag(HANDLE_TIP)[0]
    return -CORNER, -CORNER, max(CORNER, tip), max(CORNER, tip)
