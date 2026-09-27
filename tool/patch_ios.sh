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

with open(path, 'wb') as f:
    plistlib.dump(pl, f)

print('   Info.plist yangilandi')
PY

echo "✅ iOS sozlamalari qo'llandi"
