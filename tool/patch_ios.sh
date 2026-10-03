#!/usr/bin/env bash
# flutter create dan keyin iOS sozlamalarini qo'llaydi
set -e

PLIST="ios/Runner/Info.plist"

echo "→ Info.plist sozlanmoqda"
python3 - "$PLIST" <<'PY'
import sys, plistlib

path = sys.argv[1]
with open(path, 'rb') as f:
    pl = plistlib.load(f)

# Ilova nomi
pl['CFBundleDisplayName'] = 'Getcontact'
pl['CFBundleName'] = 'Getcontact'

# Files ilovasi orqali royxat.db ni ilovaga tashlash imkonini beradi
pl['UIFileSharingEnabled'] = True                 # iTunes/Finder orqali
pl['LSSupportsOpeningDocumentsInPlace'] = True    # Files ilovasida ko'rinadi

# Faqat portret
pl['UISupportedInterfaceOrientations'] = [
    'UIInterfaceOrientationPortrait',
]

# Qorong'i status bar
pl['UIStatusBarStyle'] = 'UIStatusBarStyleLightContent'
pl['UIViewControllerBasedStatusBarAppearance'] = False

# Face ID. Touch ID uchun alohida kalit kerak emas — iOS'da faqat Face ID
# kameradan foydalangani uchun izoh talab qiladi.
pl['NSFaceIDUsageDescription'] = \
    'Ilovaga parol yozmasdan tez va xavfsiz kirish uchun'
pl.pop('NSTouchIDUsageDescription', None)  # eski noto'g'ri kalit

with open(path, 'wb') as f:
    plistlib.dump(pl, f)

print('   Info.plist yangilandi')
PY

echo "→ iOS minimal versiyasi tekshirilmoqda (local_auth iOS 13+ talab qiladi)"
python3 - <<'PY'
import os, re

MIN = (13, 0)

def ge(v):
    try:
        parts = [int(x) for x in v.split('.')[:2]]
        while len(parts) < 2:
            parts.append(0)
        return tuple(parts) >= MIN
    except Exception:
        return False

# 1) Podfile: platform :ios, 'X' — izohda bo'lsa ham o'rnatamiz
pod = 'ios/Podfile'
if os.path.exists(pod):
    src = open(pod, encoding='utf-8').read()
    m = re.search(r"^\s*#?\s*platform :ios,\s*'([\d.]+)'", src, re.M)
    if m and ge(m.group(1)):
        print(f"   Podfile: {m.group(1)} — yetarli")
    elif m:
        src = src[:m.start()] + "\nplatform :ios, '13.0'" + src[m.end():]
        open(pod, 'w', encoding='utf-8').write(src)
        print(f"   Podfile: {m.group(1)} → 13.0")
    else:
        open(pod, 'w', encoding='utf-8').write("platform :ios, '13.0'\n" + src)
        print("   Podfile: platform :ios, '13.0' qo'shildi")
else:
    print('   Podfile topilmadi — o\'tkazib yuborildi')

# 2) Xcode loyihasi: IPHONEOS_DEPLOYMENT_TARGET faqat KO'TARILADI
proj = 'ios/Runner.xcodeproj/project.pbxproj'
if os.path.exists(proj):
    src = open(proj, encoding='utf-8').read()
    changed = 0

    def bump(m):
        global changed
        if ge(m.group(1)):
            return m.group(0)
        changed += 1
        return m.group(0).replace(m.group(1), '13.0')

    src = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);', bump, src)
    if changed:
        open(proj, 'w', encoding='utf-8').write(src)
    print(f'   project.pbxproj: {changed} joy 13.0 ga ko\'tarildi')
else:
    print('   project.pbxproj topilmadi — o\'tkazib yuborildi')
PY

echo "✅ iOS sozlamalari qo'llandi"
