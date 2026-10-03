name: iOS IPA

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Platforma papkalarini yaratish
        run: flutter create --platforms=ios --project-name=getcontact .

      - name: iOS sozlamalarini qo'llash
        run: bash tool/patch_ios.sh

      - name: Paketlar
        run: flutter pub get

      # DIQQAT: pubspec.yaml dagi konfiguratsiya Android uchun mo'ljallangan.
      # Bu runner'da android/ papkasi yo'q, shuning uchun iOS'ning
      # o'z konfiguratsiya fayllarini ishlatamiz (-f / --path).
      - name: Ikonka va yuklash ekrani (faqat iOS)
        run: |
          dart run flutter_launcher_icons -f tool/icons_ios.yaml
          dart run flutter_native_splash:create --path=tool/splash_ios.yaml

      # Podfile ba'zi Flutter versiyalarida faqat "pub get" dan keyin
      # paydo bo'ladi, shuning uchun skriptni qayta chaqiramiz (idempotent):
      # local_auth iOS 13+ talab qiladi.
      - name: iOS minimal versiyasini tasdiqlash
        run: bash tool/patch_ios.sh

      - name: CocoaPods
        run: cd ios && pod install --repo-update

      - name: IPA yig'ish (imzosiz)
        run: flutter build ios --release --no-codesign

      - name: IPA arxivlash
        run: |
          # IPA — bu ichida "Payload/<Ilova>.app" bo'lgan oddiy zip arxiv.
          # Papka nomi aynan "Payload" bo'lishi shart, aks holda
          # Sideloadly / AltStore uni o'rnata olmaydi.
          rm -rf build/ipa-work
          mkdir -p build/ipa-work/Payload
          cp -r build/ios/iphoneos/Runner.app build/ipa-work/Payload/
          cd build/ipa-work
          zip -qr ../Getcontact.ipa Payload
          cd ..
          ls -lh Getcontact.ipa
          echo "IPA tayyor: build/Getcontact.ipa"

      - name: IPA'ni saqlash
        uses: actions/upload-artifact@v4
        with:
          name: getcontact-ipa
          path: build/Getcontact.ipa
