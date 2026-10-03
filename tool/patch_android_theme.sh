#!/usr/bin/env bash
# LaunchTheme/NormalTheme ni AppCompat mavzusiga o'tkazadi.
#
# Nega kerak? androidx.biometric (local_auth) Android 8 va undan pastda
# o'zining barmoq izi oynasini chizadi va u AppCompat mavzusini talab qiladi.
# Aks holda ilova biometrika oynasi chiqishi paytida qulab tushadi.
# minSdk = 24 (Android 7) bo'lgani uchun bu holat real.
#
# Nega alohida fayl? flutter_native_splash:create styles.xml ni qaytadan
# yozadi, shuning uchun bu skript SPLASH'DAN KEYIN ishga tushirilishi shart.
#
# appcompat kutubxonasi alohida qo'shilmaydi — u androidx.biometric orqali
# transitiv keladi.
set -e

patched=0
for f in android/app/src/main/res/values/styles.xml \
         android/app/src/main/res/values-night/styles.xml; do
  [ -f "$f" ] || continue
  python3 - "$f" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path, encoding='utf-8').read()

# LaunchTheme va NormalTheme ning parent'ini AppCompat'ga almashtiramiz,
# ichidagi <item> larga tegmaymiz (splash fon rasmi shu yerda).
def fix(m):
    return f'<style name="{m.group(1)}" parent="Theme.AppCompat.DayNight.NoActionBar">'

new = re.sub(r'<style\s+name="(LaunchTheme|NormalTheme)"\s+parent="[^"]*">',
             fix, src)

if new == src:
    print(f'   {path}: o\'zgarish kerak emas')
else:
    open(path, 'w', encoding='utf-8').write(new)
    print(f'   {path}: AppCompat mavzusi qo\'yildi')
PY
  patched=1
done

if [ "$patched" = "0" ]; then
  echo "   styles.xml topilmadi — o'tkazib yuborildi"
fi

echo "✅ Android mavzusi AppCompat'ga o'tkazildi"
