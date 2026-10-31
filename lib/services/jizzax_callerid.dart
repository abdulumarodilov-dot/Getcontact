import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:callerid_ios/callerid_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_service.dart';

/// iPhone'da qo'ng'iroq ekranida ism ko'rsatish (Call Directory) uchun
/// ro'yxat: manzili Jizzax viloyati bo'lgan abonentlar.
///
/// iOS bitta extension'ga taxminan 1–2 mln raqam qabul qiladi, shuning
/// uchun butun baza emas, faqat shu viloyat olinadi.
class JizzaxCallerId {
  JizzaxCallerId._();

  static const fileName = 'callerid.bin';

  /// Manzil ustunida qidiriladigan bo'laklar. SQLite LIKE lotin harflarida
  /// katta-kichikni farqlamaydi, kirillda farqlaydi — shuning uchun
  /// kirill variantlari ikki xil yozilgan.
  ///   Jizzax, JIZZAKH, Jizak, Djizak, Dzhizak
  ///   Жиззах, ЖИЗЗАХ, Джизак, ДЖИЗАКСКАЯ
  static const patterns = [
    '%jizza%',
    '%jizak%',
    '%djiza%',
    '%dzhiza%',
    '%изза%',
    '%ИЗЗА%',
    '%жизак%',
    '%ЖИЗАК%',
  ];

  /// iOS chegarasi (amalda ~1.5–2 mln). Undan oshsa ogohlantiramiz.
  static const softLimit = 2000000;

  static const _chunk = 250000; // bir so'rovda ko'riladigan qatorlar (rowid)
  static const _maxLabel = 60;

  static const _kCount = 'jizzax_cid_count';
  static const _kTime = 'jizzax_cid_time';

  /// Oxirgi tayyorlangan ro'yxat: (raqamlar soni, vaqt) yoki null.
  static Future<(int, DateTime)?> lastBuild() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getInt(_kCount);
    final t = p.getInt(_kTime);
    if (n == null || t == null) return null;
    return (n, DateTime.fromMillisecondsSinceEpoch(t));
  }

  /// Bazadagi raqamni iOS ko'rinishiga keltiradi: 998XXXXXXXXX.
  static int? normalizePhone(Object? raw) {
    if (raw == null) return null;
    final d = raw.toString().replaceAll(RegExp(r'\D'), '');
    String? full;
    if (d.length == 9) {
      full = '998$d';
    } else if (d.length == 12 && d.startsWith('998')) {
      full = d;
    } else if (d.length == 14 && d.startsWith('00998')) {
      full = d.substring(2);
    }
    return full == null ? null : int.parse(full);
  }

  static String _label(Object? raw) {
    var s = (raw ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > _maxLabel) s = s.substring(0, _maxLabel).trimRight();
    return s;
  }

  /// Ro'yxatni tayyorlab, extension'ni qayta yuklaydi.
  ///
  /// [onProgress] — (0..1 ulush, topilgan raqamlar soni, bosqich matni).
  /// Qaytaradi: topilgan raqamlar soni. Xatoda [CallerIdException].
  static Future<int> build(
      void Function(double, int, String) onProgress) async {
    final container = await CallerIdIos.containerPath();
    if (container == null) {
      throw const CallerIdException(
          "Umumiy papka (App Group) ishlamayapti. Ilova App Group'ni "
          "qo'llaydigan usulda o'rnatilmagan — AltStore yoki SideStore "
          "orqali o'rnatib ko'ring.");
    }

    final db = DbService.instance;
    if (!db.isOpen) {
      final r = await db.open();
      if (!r.isOk) {
        throw const CallerIdException(
            "Baza ochilmagan. Avval qidiruv ekranida bazani oching.");
      }
    }

    // Kerakli ustunlar bormi?
    final cols = (await db.rawQuery('PRAGMA table_info("$kTable")'))
        .map((r) => (r['name'] ?? '').toString().toLowerCase())
        .toSet();
    for (final c in const ['telefon', 'abonent', 'adres']) {
      if (!cols.contains(c)) {
        throw CallerIdException("Bazada '$c' ustuni yo'q");
      }
    }

    final maxRow = ((await db.rawQuery(
                'SELECT max(rowid) AS m FROM "$kTable"'))
            .first['m'] as int?) ??
        0;
    if (maxRow == 0) throw const CallerIdException('Baza bo\'sh');

    final where = List.filled(patterns.length, '"adres" LIKE ?').join(' OR ');
    final sql = 'SELECT "telefon", "abonent" FROM "$kTable" '
        'WHERE rowid > ? AND rowid <= ? AND ($where)';

    // Bir raqam bir necha marta uchrasa — birinchi topilgan ism qoladi
    final found = <int, String>{};

    await CallerIdIos.keepAwake(true);
    try {
      for (var lo = 0; lo < maxRow; lo += _chunk) {
        final rows =
            await db.rawQuery(sql, [lo, lo + _chunk, ...patterns]);
        for (final r in rows) {
          final n = normalizePhone(r['telefon']);
          if (n == null) continue;
          final name = _label(r['abonent']);
          if (name.isEmpty) continue;
          found.putIfAbsent(n, () => name);
        }
        final done = ((lo + _chunk) / maxRow).clamp(0.0, 1.0);
        onProgress(done * 0.9, found.length, 'Bazadan qidirilmoqda');
      }

      if (found.isEmpty) {
        throw const CallerIdException(
            "Manzilida Jizzax yozilgan raqam topilmadi");
      }

      onProgress(0.92, found.length, 'Fayl yozilmoqda');
      await _writeFile('$container/$fileName', found);

      onProgress(0.95, found.length, "iOS'ga yuklanmoqda");
      final err = await CallerIdIos.reload();
      if (err != null) throw CallerIdException(err);

      final p = await SharedPreferences.getInstance();
      await p.setInt(_kCount, found.length);
      await p.setInt(_kTime, DateTime.now().millisecondsSinceEpoch);

      onProgress(1, found.length, 'Tayyor');
      return found.length;
    } finally {
      await CallerIdIos.keepAwake(false);
    }
  }

  /// Ro'yxatni o'chiradi (bo'sh fayl) va extension'ni qayta yuklaydi.
  static Future<String?> clear() async {
    final container = await CallerIdIos.containerPath();
    if (container != null) {
      await _writeFile('$container/$fileName', const {});
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCount);
    await p.remove(_kTime);
    return CallerIdIos.reload();
  }

  /// Format CallDirectoryHandler.swift dagi bilan aynan bir xil:
  ///   "GCCD" | u32 versiya=1 | u32 N | i64[N] raqamlar |
  ///   u32[N+1] ism boshlanishlari | UTF-8 ismlar
  static Future<void> _writeFile(String path, Map<int, String> data) async {
    final keys = data.keys.toList()..sort();
    final n = keys.length;

    final header = ByteData(12)
      ..setUint8(0, 0x47) // G
      ..setUint8(1, 0x43) // C
      ..setUint8(2, 0x43) // C
      ..setUint8(3, 0x44) // D
      ..setUint32(4, 1, Endian.little)
      ..setUint32(8, n, Endian.little);

    final numbers = ByteData(8 * n);
    final offsets = ByteData(4 * (n + 1));
    final labels = BytesBuilder(copy: false);

    for (var i = 0; i < n; i++) {
      numbers.setInt64(8 * i, keys[i], Endian.little);
      offsets.setUint32(4 * i, labels.length, Endian.little);
      labels.add(utf8.encode(data[keys[i]]!));
    }
    offsets.setUint32(4 * n, labels.length, Endian.little);

    // Avval vaqtinchalik faylga, keyin almashtiramiz — extension yarim
    // yozilgan faylni o'qib qolmasin
    final tmp = File('$path.tmp');
    final sink = tmp.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(numbers.buffer.asUint8List());
    sink.add(offsets.buffer.asUint8List());
    sink.add(labels.takeBytes());
    await sink.flush();
    await sink.close();
    await tmp.rename(path);
  }
}

class CallerIdException implements Exception {
  final String message;
  const CallerIdException(this.message);
  @override
  String toString() => message;
}
