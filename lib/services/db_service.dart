import 'dart:io';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:file_picker/file_picker.dart';

const List<String> kDbNames = ['royxat.db', 'ochiq.db'];
const String kTable = 'royxat';
const int kMaxResults = 200;

/// Bitta yozuv: (ustun nomi, qiymat) juftliklari.
/// Diqqat: `Record` nomi Dart 3'da band, shuning uchun `DbRecord`.
typedef DbRecord = List<MapEntry<String, String>>;

/// Bazani ochish natijasi
enum DbState {
  /// Baza ochildi, ishlatishga tayyor
  ok,

  /// Fayl topilmadi
  notFound,

  /// Fayl bor, lekin shifrlangan — parol kerak
  needKey,

  /// Saqlangan parol noto'g'ri (baza almashtirilgan bo'lishi mumkin)
  wrongKey,

  /// Boshqa xato
  error,
}

class DbResult {
  final DbState state;
  final String? message;
  const DbResult(this.state, [this.message]);

  bool get isOk => state == DbState.ok;
}

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  static const _keyName = 'royxat_db_key';
  static const _secure = FlutterSecureStorage();

  String? _path;
  Database? _db;

  String? get path => _path;
  bool get isOpen => _db != null;

  // ──────────────────────────────────────────────────────────
  // Kalitni xavfsiz saqlash (Android Keystore / iOS Keychain)
  // ──────────────────────────────────────────────────────────

  Future<String?> _loadKey() async {
    try {
      return await _secure.read(key: _keyName);
    } catch (e) {
      debugPrint('Kalitni o\'qishda xato: $e');
      return null;
    }
  }

  /// Saqlangani haqida xabar qaytaradi — imzosiz iOS build'da
  /// Keychain ruxsati bo'lmaydi va yozish jimgina muvaffaqiyatsiz bo'ladi.
  Future<bool> _saveKey(String key) async {
    try {
      await _secure.write(key: _keyName, value: key);
      return true;
    } catch (e) {
      debugPrint('Kalitni saqlashda xato: $e');
      return false;
    }
  }

  /// Saqlangan baza parolini o'chirish — keyingi ochishda qaytadan so'raladi
  Future<void> forgetKey() async {
    try {
      await _secure.delete(key: _keyName);
    } catch (e) {
      debugPrint('Kalitni o\'chirishda xato: $e');
    }
    await close();
  }

  Future<bool> hasStoredKey() async => (await _loadKey()) != null;

  // ──────────────────────────────────────────────────────────
  // Fayl yo'llari
  // ──────────────────────────────────────────────────────────

  /// Ilova o'z papkasi — iOS'da yagona mumkin bo'lgan joy
  Future<String> appDbDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Bazani qidirish. Android'da tashqi xotira ham tekshiriladi,
  /// iOS'da faqat ilovaning Documents papkasi.
  Future<String?> findDatabase() async {
    final candidates = <String>[];

    // Har ikkala platformada: ilova papkasi
    candidates.add(await appDbDir());

    if (Platform.isAndroid) {
      candidates.addAll([
        '/storage/emulated/0/qidiruv',
        '/sdcard/qidiruv',
        '/storage/emulated/0',
        '/sdcard',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
      ]);

      // Ulangan SD kartalar
      try {
        final storage = Directory('/storage');
        if (storage.existsSync()) {
          for (final e in storage.listSync()) {
            final name = p.basename(e.path);
            if (name == 'emulated' || name == 'self') continue;
            if (e is Directory) {
              candidates.add(e.path);
              candidates.add(p.join(e.path, 'qidiruv'));
            }
          }
        }
      } catch (_) {}

      // Tashqi xotira papkalari
      try {
        final dirs = await getExternalStorageDirectories();
        if (dirs != null) {
          for (final d in dirs) {
            candidates.add(d.path);
          }
        }
      } catch (_) {}
    }

    for (final dir in candidates) {
      for (final name in kDbNames) {
        final full = p.join(dir, name);
        try {
          if (File(full).existsSync()) return full;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Android'da "Barcha fayllar" ruxsatini so'rash
  Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final st = await Permission.manageExternalStorage.request();
      if (st.isGranted) return true;
      final st2 = await Permission.storage.request();
      return st2.isGranted;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // Ochish
  // ──────────────────────────────────────────────────────────

  /// Bazani ochib, haqiqatan o'qib ko'radi.
  ///
  /// SQLCipher noto'g'ri parolda `openDatabase` paytida emas, birinchi
  /// so'rovda xato beradi — shuning uchun sinov so'rovi majburiy.
  ///
  /// `singleInstance: false` — sqflite bir xil yo'l uchun ochiq nusxani
  /// qaytarib yubormasligi kerak, aks holda yangi parol e'tiborsiz qoladi.
  ///
  /// DIQQAT: `readOnly: true` ni o'zgartirmang. Faqat shu rejimda plagin
  /// "buzilgan baza" holatida faylni o'chirmaydigan error handler o'rnatadi.
  /// `readOnly: false` bilan SQLCipher noto'g'ri kalitni buzilish deb hisoblab
  /// FAYLNI O'CHIRIB YUBORADI — pastdagi 1-qadam (kalitsiz urinish) har safar
  /// foydalanuvchining shifrlangan bazasini yo'q qilgan bo'lardi.
  Future<Database?> _tryOpen(String path, String? password) async {
    Database? db;
    try {
      db = await openDatabase(
        path,
        password: (password != null && password.isEmpty) ? null : password,
        readOnly: true,
        singleInstance: false,
      );
      // Sinov so'rovi — parol noto'g'ri bo'lsa shu yerda xato chiqadi
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
      return db;
    } catch (_) {
      try {
        await db?.close();
      } catch (_) {}
      return null;
    }
  }

  /// Bazani ochish. Avval shifrlanmagan holda, keyin saqlangan kalit bilan.
  Future<DbResult> open() async {
    if (_db != null) return const DbResult(DbState.ok);

    await ensureStoragePermission();

    final found = await findDatabase();
    if (found == null) {
      return DbResult(
        DbState.notFound,
        Platform.isIOS
            ? "Baza topilmadi.\nSozlamalar → Bazani import qilish orqali royxat.db faylini yuklang."
            : "royxat.db topilmadi.\nFaylni /sdcard/qidiruv/ papkasiga qo'ying\nyoki Sozlamalardan import qiling.",
      );
    }

    // 1) Shifrlanmagan baza bo'lishi mumkin
    var db = await _tryOpen(found, null);
    if (db != null) {
      _db = db;
      _path = found;
      // Shifrlanmagan baza — eski kalit endi kerak emas (sozlamalar
      // "shifrlangan" deb yolg'on ko'rsatmasligi uchun)
      await forgetKeyOnly();
      return const DbResult(DbState.ok);
    }

    // Fayl topildi — unlock() qayta qidirmasligi uchun eslab qolamiz
    _path = found;

    // 2) Saqlangan kalit bilan
    final key = await _loadKey();
    if (key == null) {
      return const DbResult(
        DbState.needKey,
        'Baza shifrlangan. Parolni kiriting.',
      );
    }

    db = await _tryOpen(found, key);
    if (db != null) {
      _db = db;
      return const DbResult(DbState.ok);
    }

    return const DbResult(
      DbState.wrongKey,
      "Saqlangan parol bu bazaga to'g'ri kelmadi. Qaytadan kiriting.",
    );
  }

  /// Foydalanuvchi kiritgan parol bilan ochishga urinish.
  /// Muvaffaqiyatli bo'lsa parol xavfsiz xotiraga saqlanadi.
  Future<DbResult> unlock(String password) async {
    final found = _path ?? await findDatabase();
    if (found == null) {
      return const DbResult(DbState.notFound, 'Baza fayli topilmadi');
    }

    // Eski ulanishni hozircha yopmaymiz — yangi parol noto'g'ri chiqsa
    // foydalanuvchi ishlayotgan bazasidan ayrilmasligi kerak
    final existing = _db;
    _db = null;

    final db = await _tryOpen(found, password);
    if (db == null) {
      _db = existing;
      return const DbResult(DbState.wrongKey, "Parol noto'g'ri");
    }

    try {
      await existing?.close();
    } catch (_) {}

    _db = db;
    _path = found;

    final saved = await _saveKey(password);
    return saved
        ? const DbResult(DbState.ok)
        : const DbResult(
            DbState.ok,
            "Baza ochildi, lekin parolni saqlab bo'lmadi — "
            "keyingi safar qaytadan so'raladi.",
          );
  }

  Future<void> close() async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
  }

  // ──────────────────────────────────────────────────────────
  // Import
  // ──────────────────────────────────────────────────────────

  /// Foydalanuvchidan .db faylni tanlashni so'raydi.
  /// Tanlangan faylning yo'lini qaytaradi (hali ko'chirilmagan).
  Future<String?> pickDatabaseFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files == null || files.isEmpty) return null;

      final picked = files.first.path;
      if (picked == null) return null;

      final ext = p.extension(picked).toLowerCase();
      if (ext != '.db' && ext != '.sqlite' && ext != '.sqlite3') return null;

      return picked;
    } catch (e) {
      debugPrint('Fayl tanlashda xato: $e');
      return null;
    }
  }

  /// Tanlangan faylni tekshirib, ilova papkasiga o'rnatadi.
  ///
  /// `password` bo'sh bo'lsa shifrlanmagan deb qaraladi.
  /// Tekshiruvdan o'tmasa eski baza tegilmaydi.
  Future<DbResult> installDatabase(String srcPath, String password) async {
    try {
      final src = File(srcPath);
      if (!src.existsSync()) {
        return const DbResult(DbState.error, 'Fayl topilmadi');
      }

      final dstDir = await appDbDir();
      final dst = p.join(dstDir, 'royxat.db');
      final tmp = p.join(dstDir, 'royxat.db.tmp');

      // Avval vaqtinchalik faylga — yaroqsiz fayl eski bazani buzmasligi uchun
      await src.copy(tmp);

      final test = await _tryOpen(tmp, password.isEmpty ? null : password);
      if (test == null) {
        await _safeDelete(tmp);
        return const DbResult(
          DbState.wrongKey,
          "Ochib bo'lmadi — parol noto'g'ri yoki fayl buzilgan",
        );
      }

      List<Map<String, Object?>> tables;
      try {
        tables = await test.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [kTable],
        );
      } catch (e) {
        await _safeDelete(tmp);
        return DbResult(DbState.error, 'Jadvalni tekshirishda xato: $e');
      } finally {
        // singleInstance: false — bu nusxani sqflite kuzatmaydi,
        // o'zimiz yopmasak jarayon oxirigacha ochiq qoladi
        try {
          await test.close();
        } catch (_) {}
      }

      if (tables.isEmpty) {
        await _safeDelete(tmp);
        return const DbResult(
          DbState.error,
          "Bazada '$kTable' jadvali topilmadi",
        );
      }

      // Tekshiruvdan o'tdi — endi almashtiramiz.
      // rename() bir papka ichida atomar: dst ni oldindan o'chirmaymiz,
      // aks holda ikkala fayl ham yo'q bo'lgan oraliq paydo bo'ladi.
      await close();
      await File(tmp).rename(dst);
      _path = dst;

      if (password.isEmpty) {
        await forgetKeyOnly();
      } else {
        await _saveKey(password);
      }

      final db = await _tryOpen(dst, password.isEmpty ? null : password);
      if (db == null) {
        return const DbResult(DbState.error, "O'rnatishdan keyin ochilmadi");
      }

      _db = db;
      return const DbResult(DbState.ok);
    } catch (e) {
      return DbResult(DbState.error, 'Import xatosi: $e');
    }
  }

  /// Kalitni o'chiradi, lekin ochiq bazani yopmaydi
  Future<void> forgetKeyOnly() async {
    try {
      await _secure.delete(key: _keyName);
    } catch (_) {}
  }

  /// Faylni va SQLite yon fayllarini o'chiradi.
  /// Qolib ketgan `-wal` yangi bazani ochishga xalaqit beradi.
  Future<void> _safeDelete(String path) async {
    for (final f in [path, '$path-journal', '$path-shm', '$path-wal']) {
      try {
        final file = File(f);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────
  // Lotin ↔ Kiril transliteratsiya
  // ──────────────────────────────────────────────────────────

  /// Lotin harflarini mos kiril harflariga almashtiradi (kichik harf).
  /// Faqat o'zbek alifbosiga xos harflar ko'rib chiqiladi.
  static const _latinToCyrillic = <String, String>{
    "a": "а", "b": "б", "d": "д", "e": "е", "f": "ф",
    "g": "г", "h": "х", "i": "и", "j": "ж", "k": "к",
    "l": "л", "m": "м", "n": "н", "o": "о", "p": "п",
    "q": "қ", "r": "р", "s": "с", "t": "т", "u": "у",
    "v": "в", "x": "х", "y": "й", "z": "з",
    // Digraflar (avval tekshiriladi)
    "sh": "ш", "ch": "ч", "ng": "нг", "gh": "ғ",
    "o'": "ў", "o`": "ў", "g'": "ғ", "g`": "ғ",
  };

  static const _cyrillicToLatin = <String, String>{
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d",
    "е": "e", "ё": "yo", "ж": "j", "з": "z", "и": "i",
    "й": "y", "к": "k", "л": "l", "м": "m", "н": "n",
    "о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
    "у": "u", "ф": "f", "х": "x", "ц": "ts", "ч": "ch",
    "ш": "sh", "щ": "sh", "ъ": "", "ы": "i", "ь": "",
    "э": "e", "ю": "yu", "я": "ya",
    "ғ": "g'", "қ": "q", "ҳ": "h", "ў": "o'", "ъ": "",
  };

  // ──────────────────────────────────────────────────────────
  // O'zbek fonetik ekvivalentlari (bir tovush — bir necha yozuv)
  // ──────────────────────────────────────────────────────────

  /// Lotin harfi → unga fonetik ekvivalent lotin harflari ro'yxati.
  /// Masalan: "q" yozsangiz bazada "k" yoki "q" bo'lishi mumkin.
  static const _latinEquiv = <String, List<String>>{
    // Qattiq/yumshoq juftliklar
    'q': ['q', 'k'],     // qurbonov / kurbonov
    'k': ['k', 'q'],
    'x': ['x', 'h'],     // xasan / hasan
    'h': ['h', 'x'],
    "o'": ["o'", 'u', 'o'], // o'g'li / ugli
    'u':  ['u', "o'"],
    "g'": ["g'", 'g'],   // g'ayrat / gayrat
    'g': ['g', "g'"],
  };

  /// Kiril harfi → fonetik ekvivalent kiril harflari.
  static const _cyrillicEquiv = <String, List<String>>{
    'қ': ['қ', 'к'],
    'к': ['к', 'қ'],
    'х': ['х', 'ҳ'],
    'ҳ': ['ҳ', 'х'],
    'ў': ['ў', 'у', 'о'],
    'у': ['у', 'ў'],
    'ғ': ['ғ', 'г'],
    'г': ['г', 'ғ'],
  };

  /// Matnni LIKE pattern'ga aylantiradi: fonetik ekvivalent harflar
  /// o'rniga `%` qo'yiladi, shunda SQLite bir belgini har ikkala
  /// variantda topadi.
  ///
  /// Misol: "qurbonov" → "k%rbono%" (q→k%, o'→u sababli oxirgi v ham %)
  /// Amalda har bir ekvivalent harfni `_` (bir belgi wildcard) bilan
  /// almashtiramiz, `%` emas — chunki biz belgini O'CHIRMAYMIZ, almashtirAMIZ.
  static String _fuzzyPattern(String lower, {required bool cyrillic}) {
    final equiv = cyrillic ? _cyrillicEquiv : _latinEquiv;
    final buf = StringBuffer();
    var i = 0;

    while (i < lower.length) {
      bool found = false;
      // Avval 3, keyin 2 belgili digraflarni tekshir
      for (final len in [3, 2]) {
        if (i + len <= lower.length) {
          final sub = lower.substring(i, i + len);
          if (equiv.containsKey(sub)) {
            buf.write('_'); // Bir belgiga o'xshash wildcard (tovush bitta)
            i += len;
            found = true;
            break;
          }
        }
      }
      if (!found) {
        final single = lower[i];
        if (equiv.containsKey(single)) {
          buf.write('_'); // Fonetik ekvivalent — wildcard
        } else {
          buf.write(single); // Oddiy harf — o'ziga o'zi
        }
        i++;
      }
    }
    return buf.toString();
  }

  /// Kiritilgan so'zni LIKE pattern variantlari ro'yxatiga aylantiradi:
  /// asl + lotin↔kiril tarjimasi + fuzzy pattern.
  static List<String> _searchPatterns(String raw) {
    final lower = raw.toLowerCase().trim();
    final patterns = <String>{};

    // ── 1. Asl matn (lotin yoki kiril) ──────────────────────
    patterns.add('%$lower%');

    // ── 2. Kiril → Lotin ────────────────────────────────────
    final buf1 = StringBuffer();
    for (final c in lower.characters) {
      buf1.write(_cyrillicToLatin[c] ?? c);
    }
    final asLatin = buf1.toString();
    patterns.add('%$asLatin%');

    // ── 3. Lotin → Kiril (digraflarni avval) ─────────────────
    final buf2 = StringBuffer();
    var j = 0;
    while (j < lower.length) {
      bool found = false;
      for (final len in [3, 2]) {
        if (j + len <= lower.length) {
          final sub = lower.substring(j, j + len);
          if (_latinToCyrillic.containsKey(sub)) {
            buf2.write(_latinToCyrillic[sub]);
            j += len;
            found = true;
            break;
          }
        }
      }
      if (!found) {
        buf2.write(_latinToCyrillic[lower[j]] ?? lower[j]);
        j++;
      }
    }
    final asCyrillic = buf2.toString();
    patterns.add('%$asCyrillic%');

    // ── 4. Fuzzy: lotin variantida fonetik wildcard ──────────
    final fuzzyLatin = _fuzzyPattern(asLatin, cyrillic: false);
    patterns.add('%$fuzzyLatin%');

    // ── 5. Fuzzy: kiril variantida fonetik wildcard ──────────
    final fuzzyCyrillic = _fuzzyPattern(asCyrillic, cyrillic: true);
    patterns.add('%$fuzzyCyrillic%');

    return patterns.toList();
  }

  // ──────────────────────────────────────────────────────────
  // Qidiruv
  // ──────────────────────────────────────────────────────────

  /// Foydalanuvchi `%` yozganmi tekshiradi.
  /// `%urb%nov` → true (manual wildcard rejimi)
  static bool _hasWildcard(String q) => q.contains('%') || q.contains('_');

  /// `abonent` ustuni uchun:
  ///   • `%` bo'lsa — foydalanuvchi o'zi LIKE pattern yozgan,
  ///     to'g'ridan-to'g'ri shu pattern bilan qidiradi.
  ///   • `%` bo'lmasa — lotin/kiril + fonetik fuzzy variantlar.
  /// Boshqa ustunlar uchun aniq moslik.
  Future<List<DbRecord>> search(String column, String query) async {
    final db = _db;
    if (db == null) throw StateError('Baza ochilmagan');

    List<Map<String, Object?>> rows;

    if (column == 'abonent') {
      if (_hasWildcard(query)) {
        // ── Manual wildcard rejimi: %urb%nov ──────────────────
        // Foydalanuvchi o'zi % qo'ygan — bir pattern, to'g'ridan-to'g'ri LIKE
        rows = await db.rawQuery(
          'SELECT * FROM "$kTable" WHERE lower("$column") LIKE lower(?) LIMIT $kMaxResults',
          [query.toLowerCase()],
        );
      } else {
        // ── Avtomatik: lotin/kiril + fonetik fuzzy ────────────
        final patterns = _searchPatterns(query);
        final conditions = patterns
            .map((_) => 'lower("$column") LIKE lower(?)')
            .toList();
        final sql =
            'SELECT * FROM "$kTable" WHERE ${conditions.join(' OR ')} LIMIT $kMaxResults';
        rows = await db.rawQuery(sql, patterns);
      }
    } else {
      // Telefon, pasport, jshshir — aniq moslik
      rows = await db.rawQuery(
        'SELECT * FROM "$kTable" WHERE "$column" = ? LIMIT $kMaxResults',
        [query],
      );
    }

    // Takroriy satrlarni olib tashlash (bir necha variant bir qatorni topsa)
    final seen = <Object?>{};
    final out = <DbRecord>[];
    for (final row in rows) {
      final id = row['rowid'] ?? row.values.join('\x00');
      if (!seen.add(id)) continue;

      final rec = <MapEntry<String, String>>[];
      row.forEach((key, value) {
        if (value == null) return;
        final s = value.toString().trim();
        if (s.isEmpty) return;
        rec.add(MapEntry(key, s));
      });
      if (rec.isNotEmpty) out.add(rec);
    }
    return out;
  }
}
