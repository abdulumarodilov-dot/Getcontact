#!/usr/bin/env bash
# flutter create dan keyin Android sozlamalarini qo'llaydi
set -e

MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE_KTS="android/app/build.gradle.kts"
GRADLE="android/app/build.gradle"

echo "→ AndroidManifest.xml yangilanmoqda (ruxsatlar + icon + label)"
python3 - "$MANIFEST" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path, encoding='utf-8').read()

# 1) Ruxsatlar
perms = '''    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />     ← YANGI
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />   ← YANGI
'''
if 'MANAGE_EXTERNAL_STORAGE' not in src:
    i = src.index('>', src.index('<manifest')) + 1
    src = src[:i] + '\n' + perms + src[i:]
    print('   Ruxsatlar qo\'shildi')

# 2) Ilova nomi
src = re.sub(r'android:label="[^"]*"', 'android:label="Getcontact"', src, count=1)

# 3) <application tegiga barcha atributlarni birdan qo'shamiz
# (requestLegacyExternalStorage + icon + roundIcon)
app_tag = '<application'
extra_attrs = ''
if 'android:icon="@mipmap/ic_launcher"' not in src:
    extra_attrs += '\n        android:icon="@mipmap/ic_launcher"'
    extra_attrs += '\n        android:roundIcon="@mipmap/ic_launcher_round"'
if 'requestLegacyExternalStorage' not in src:
    extra_attrs += '\n        android:requestLegacyExternalStorage="true"'

if extra_attrs:
    src = src.replace(app_tag, app_tag + extra_attrs, 1)
    print(f'   application atributlari qo\'shildi:{extra_attrs}')
else:
    print('   application atributlari allaqachon mavjud')

open(path, 'w', encoding='utf-8').write(src)
print('   AndroidManifest.xml yangilandi')
PY

echo "→ minSdk sozlanmoqda"
for f in "$GRADLE_KTS" "$GRADLE"; do
  if [ -f "$f" ]; then
    python3 - "$f" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path, encoding='utf-8').read()
src = re.sub(r'minSdk(Version)?\s*=?\s*[\w.]+', 'minSdk = 24'
             if path.endswith('.kts') else 'minSdkVersion 24', src)
open(path, 'w', encoding='utf-8').write(src)
print(f'   {path} yangilandi')
PY
  fi
done

echo "→ SQLCipher uchun ProGuard qoidalari"
cat > android/app/proguard-rules.pro <<'EOF'
# SQLCipher — R8 sinflarni o'chirib yubormasligi uchun.
# sqflite_sqlcipher 3.x "net.zetetic:sqlcipher-android" ishlatadi,
# eski "net.sqlcipher" emas — paket nomi shuning uchun boshqacha.
-keep,includedescriptorclasses class net.zetetic.database.** { *; }
-keepclasseswithmembernames class net.zetetic.database.** {
    native <methods>;
}
-dontwarn net.zetetic.database.**

# flutter_secure_storage v11 — Google Tink
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
EOF
echo "   proguard-rules.pro yaratildi"
# local_auth — biometric authentication
-keep class io.flutter.embedding.engine.plugins.shim.** { *; }
python3 - "$GRADLE_KTS" "$GRADLE" <<'PY'
import os, re, sys

for path in sys.argv[1:]:
    if not os.path.exists(path):
        continue
    src = open(path, encoding='utf-8').read()
    if 'proguard-rules.pro' in src:
        print(f'   {path}: allaqachon ulangan')
        continue

    kts = path.endswith('.kts')
    if kts:
        line = ('\n            proguardFiles(\n'
                '                getDefaultProguardFile("proguard-android-optimize.txt"),\n'
                '                "proguard-rules.pro"\n'
                '            )')
    else:
        line = ('\n            proguardFiles '
                'getDefaultProguardFile("proguard-android-optimize.txt"), '
                '"proguard-rules.pro"')

    # buildTypes { ... release { ... } } ichidagi release blokini topamiz
    m = re.search(r'buildTypes\s*\{', src)
    if not m:
        print(f'   {path}: buildTypes bloki topilmadi, o\'tkazib yuborildi')
        continue

    rel = re.search(r'release\s*\{', src[m.end():])
    if not rel:
        print(f'   {path}: release bloki topilmadi, o\'tkazib yuborildi')
        continue

    pos = m.end() + rel.end()
    src = src[:pos] + line + src[pos:]
    open(path, 'w', encoding='utf-8').write(src)
    print(f'   {path}: proguardFiles qo\'shildi')
PY

echo "✅ Android sozlamalari qo'llandi"
