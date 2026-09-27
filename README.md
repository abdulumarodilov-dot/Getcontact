# Getcontact — Flutter versiyasi

Kivy ilovasining Flutter'ga ko'chirilgan versiyasi. Bitta koddan **Android** va **iOS** uchun ilova chiqadi.

---

## Nima o'zgardi

| Kivy (eski) | Flutter (yangi) |
|---|---|
| `buildozer` + `python-for-android` | `flutter build` |
| `sqlite3` (shifrlanmagan) | `sqflite_sqlcipher` — **AES-256** |
| `threading.Thread` | `async/await` (UI qotmaydi) |
| Parol `.txt` faylda | `SharedPreferences` |
| Canvas'da qo'lda chizilgan ikonkalar | Material ikonkalar |
| Faqat Android | Android **+ iOS** |

Barcha dizayn ranglari va o'lchamlari aynan ko'chirildi — ilova xuddi shunday ko'rinadi.

---

## Ishga tushirish

### 1. Flutter o'rnatish
https://docs.flutter.dev/get-started/install

### 2. Loyihani tayyorlash

```bash
cd getcontact

# Platforma papkalarini yaratish (android/ va ios/)
flutter create --platforms=android,ios .

# Sozlamalarni qo'llash
bash tool/patch_android.sh
bash tool/patch_ios.sh      # faqat macOS'da kerak

# Paketlar
flutter pub get

# Ikonka va yuklash ekrani
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### 3. Yig'ish

```bash
flutter build apk --release        # Android APK
flutter build ios --release        # iOS (faqat Mac'da)
```

---

## GitHub Actions

Ikkita workflow tayyor:

| Fayl | Nima qiladi | Qachon ishga tushadi |
|---|---|---|
| `.github/workflows/android.yml` | APK yig'adi | Har `push` da |
| `.github/workflows/ios.yml` | iOS `.app` yig'adi | Faqat qo'lda (**Actions → iOS → Run workflow**) |

iOS build ~20-30 daqiqa davom etadi va **imzosiz** `.app` chiqaradi — u faqat Mac simulyatorida ishlaydi.

---

## Bazani AES bilan shifrlash

Ilova **SQLCipher** ishlatadi — butun `.db` fayl AES-256 bilan shifrlanadi va ilova uni o'qiyotganda real vaqtda deshifrlaydi. Diskda hech qachon ochiq nusxa paydo bo'lmaydi.

### 1. `royxat.db` ni shifrlash

**DB Browser for SQLCipher** orqali:

1. **Avval zaxira nusxa oling** — `royxat.db` ni boshqa joyga ko'chiring
2. DB Browser for SQLCipher'ni oching → **File → Open Database** → `royxat.db`
3. **File → Set Encryption...**
4. Parolni ikki marta kiriting
5. **Muhim:** oynadagi sozlamalar **SQLCipher 4** bo'lsin (Page size `4096`, KDF iterations `256000`, HMAC `SHA512`, KDF `SHA512`). Bu standart qiymatlar — o'zgartirmang
6. **OK** → **Write Changes** (Ctrl+S) → **Close Database**

**Tekshirish:** faylni qaytadan oching — DB Browser parol so'rashi kerak. So'ramasa, shifrlanmagan.

> **Diqqat:** ilova bazani faqat o'qish rejimida ochadi, shuning uchun SQLCipher 3 formatini avtomatik yangilay olmaydi. Agar sozlamalar SQLCipher 3 da qolsa yoki KDF iterations / page size standartdan farq qilsa, parol to'g'ri bo'lsa ham **"Parol noto'g'ri"** deb ko'rsatiladi. Bunday holda DB Browser'da bazani SQLCipher 4 standart sozlamalari bilan qaytadan shifrlang.

### 2. Ilovada ochish

1. Shifrlangan `royxat.db` ni telefonga ko'chiring (yoki Sozlamalar → Import)
2. Birinchi qidiruvda ilova **baza parolini** so'raydi
3. Parol qurilmaning xavfsiz xotirasiga saqlanadi — **Android Keystore** / **iOS Keychain**
4. Keyingi safar so'ralmaydi

Parolni almashtirish kerak bo'lsa: **Sozlamalar → Saqlangan parolni o'chirish**.

### Xavfsizlik haqida ochiq gap

| Nimadan himoya qiladi | Nimadan himoya qilmaydi |
|---|---|
| Telefondan `.db` faylni nusxalab olgan odam uni ocha olmaydi | Ilovaga parol bilan kirgan odam hamma narsani ko'radi |
| Yo'qolgan/o'g'irlangan telefon | Root qilingan qurilmada xotirani skanerlash |
| Zaxira nusxalar orqali sizib chiqish | Ekrandan surat olish |

Kalit ilovada saqlanmaydi — foydalanuvchi kiritadi va u OS'ning shifrlangan xotirasiga tushadi. Bu APK ichiga kalit yozishdan ancha kuchli: `.apk` faylni ochib tahlil qilgan odam parolni topa olmaydi.

---

## Bazani joylash

### Android
`royxat.db` faylni quyidagi papkalardan biriga qo'ying:

- `/sdcard/qidiruv/royxat.db` ← tavsiya etiladi
- `/sdcard/royxat.db`
- `/sdcard/Download/royxat.db`

Ilova birinchi ochilganda **"Barcha fayllar"** ruxsatini so'raydi — ruxsat bering.

Ruxsat bermoqchi bo'lmasangiz: **Sozlamalar → Bazani import qilish** orqali ham yuklash mumkin.

### iOS
iOS'da ilova tashqi papkalarni ko'ra olmaydi. Ikki yo'l bor:

1. **Ilova ichidan:** Sozlamalar → **Bazani import qilish** → `royxat.db` ni tanlang
2. **Files ilovasi orqali:** `royxat.db` ni `Files → On My iPhone → Getcontact` papkasiga ko'chiring

---

## iOS'ni haqiqiy iPhone'ga o'rnatish

Buning uchun **Apple Developer** akkaunti kerak (**$99/yil**):

1. https://developer.apple.com da ro'yxatdan o'ting
2. Xcode'da loyihani oching: `open ios/Runner.xcworkspace`
3. **Signing & Capabilities** → jamoangizni tanlang
4. `flutter build ipa` → `.ipa` fayl tayyor
5. **TestFlight** yoki **App Store Connect** orqali tarqating

> Akkauntsiz ham Xcode orqali o'z iPhone'ingizga o'rnatish mumkin, lekin ilova **7 kundan keyin ishlamay qoladi**.

---

## Loyiha tuzilishi

```
lib/
├── main.dart                    # kirish nuqtasi
├── theme.dart                   # ranglar + gradient fon
├── models/
│   └── field_meta.dart          # ustun nomlari va ikonkalari
├── services/
│   ├── db_service.dart          # SQLCipher: ochish, kalit, qidiruv, import
│   └── auth_service.dart        # kirish paroli (SHA-256)
├── screens/
│   ├── lock_screen.dart         # kirish paroli ekrani
│   ├── search_screen.dart       # asosiy qidiruv
│   └── settings_screen.dart     # sozlamalar + baza import
└── widgets/
    ├── common.dart              # tugmalar, inputlar, panellar
    ├── db_password_dialog.dart  # baza parolini so'rash oynasi
    └── result_card.dart         # natija kartochkasi + batafsil oyna
```

**Ikki xil parol bor, ularni aralashtirmang:**

| Parol | Nima uchun | Qayerda saqlanadi |
|---|---|---|
| **Kirish paroli** | Ilovani ochish | `SharedPreferences` (faqat SHA-256 hash) |
| **Baza paroli** | `royxat.db` ni deshifrlash | Keystore / Keychain (shifrlangan) |

---

## Sozlash

**Ranglar:** `lib/theme.dart` → `AppColors`

**Qidiruv ustunlari:** `lib/models/field_meta.dart` → `searchColumns`

**Jadval nomi / limit:** `lib/services/db_service.dart` → `kTable`, `kMaxResults`
