import 'dart:io';
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
  // Qidiruv
  // ──────────────────────────────────────────────────────────

  /// Matn faqat ASCII belgilardan iboratmi?
  static bool _isAscii(String s) => s.codeUnits.every((c) => c < 128);

  /// LIKE'da qochirish belgisi sifatida `\` ishlatiladi.
  /// Dart satrida bitta teskari chiziq — '\\'.
  static const String _bs = '\\';

  /// LIKE uchun pattern. `%` va `_` maxsus belgi emas — oddiy harf.
  static String _likePattern(String q) {
    final esc = q
        .replaceAll(_bs, _bs + _bs)
        .replaceAll('%', '$_bs%')
        .replaceAll('_', '${_bs}_');
    return '%$esc%';
  }

  /// GLOB uchun pattern: har bir harf `[kichik+KATTA]` sinfiga o'raladi.
  /// Masalan "Оt" → `*[оО][tT]*`
  ///
  /// Bu kerak, chunki SQLite'ning `lower()` va `LIKE` funksiyalari faqat
  /// ASCII harflarni registrsiz solishtiradi — kirilni bilmaydi.
  static String _globPattern(String q) {
    const special = '*?[]^-'; // GLOB maxsus belgilari
    final b = StringBuffer('*');
    for (final rune in q.runes) {
      final ch = String.fromCharCode(rune);
      if (special.contains(ch)) continue;
      final lo = ch.toLowerCase();
      final up = ch.toUpperCase();
      b.write(lo == up ? '[$lo]' : '[$lo$up]');
    }
    b.write('*');
    return b.toString();
  }

  /// `abonent` ustuni uchun — faqat kichik/katta harfga e'tibor bermaydigan
  /// oddiy qidiruv (matn ichidan qism sifatida izlaydi).
  /// Transliteratsiya, fuzzy va wildcard rejimlari o'chirilgan.
  ///
  /// Boshqa ustunlar (telefon, pasport, jshshir) uchun — aniq moslik.
  Future<List<DbRecord>> search(String column, String query) async {
    final db = _db;
    if (db == null) throw StateError('Baza ochilmagan');

    List<Map<String, Object?>> rows;

    if (column == 'abonent') {
      final q = query.trim();
      if (q.isEmpty) return const [];

      // Lotin uchun LIKE — SQLite uni ASCII bo'yicha o'zi registrsiz
      // solishtiradi, bu eng tez yo'l. Kiril uchun esa GLOB kerak.
      final useLike = _isAscii(q);
      final sql = useLike
          ? 'SELECT * FROM "$kTable" WHERE "$column" LIKE ? '
                "ESCAPE '$_bs' LIMIT $kMaxResults"
          : 'SELECT * FROM "$kTable" WHERE "$column" GLOB ? LIMIT $kMaxResults';

      rows = await db.rawQuery(
        sql,
        [useLike ? _likePattern(q) : _globPattern(q)],
      );
    } else {
      // Telefon, pasport, jshshir — aniq moslik
      rows = await db.rawQuery(
        'SELECT * FROM "$kTable" WHERE "$column" = ? LIMIT $kMaxResults',
        [query],
      );
    }

    // Takroriy satrlarni olib tashlash
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
