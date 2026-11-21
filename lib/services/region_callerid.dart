import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:callerid_ios/callerid_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_service.dart';

/// Bitta hudud: manzil ustunida qaysi so'zlar bo'yicha tanib olinadi.
///
/// Qoida: `stems` dan biri bo'lsa — mos. `requireAny` berilgan bo'lsa,
/// undan ham biri bo'lishi shart. `exclude` dan biri bo'lsa — mos emas.
///
/// So'zlar kichik harfda yoziladi. SQLite LIKE lotin harflarida katta-kichikni
/// farqlamaydi, kirillda esa farqlaydi — shuning uchun kirill so'zlarining
/// KATTA varianti avtomatik qo'shiladi. Kirill so'zlar ataylab birinchi
/// harfsiz yozilgan («Самарканд» → «амарк»): shunda «Самарканд» ham,
/// «САМАРКАНД» ham topiladi.
///
/// Ortiqcha topilish (masalan boshqa shahardagi «Samarqand ko'chasi») zararsiz:
/// ism baribir aynan o'sha raqamniki, faqat ro'yxat biroz kattalashadi.
class CallerRegion {
  final String id;
  final String name;
  final List<String> stems;
  final List<String> requireAny;
  final List<String> exclude;

  const CallerRegion(
    this.id,
    this.name,
    this.stems, {
    this.requireAny = const [],
    this.exclude = const [],
  });
}

/// Toshkent shahri va viloyatini ajratuvchi belgilar
const _viloyatMarkers = [
  'viloyat',
  'oblast',
  'вилоят',
  'област',
  'обл.',
  'ашкентск', // «Ташкентская»
];

const _toshkent = ['toshkent', 'tashkent', 'ашкент', 'ошкент'];

/// iPhone'da qo'ng'iroq ekranida ism ko'rsatish (Call Directory) uchun
/// ro'yxat: tanlangan hududlardagi abonentlar.
///
/// iOS bitta extension'ga cheklangan miqdordagi raqamni qabul qiladi
/// (aniq chegara e'lon qilinmagan, amalda ~1,5–2 mln). Shuning uchun:
///   • butun baza emas, faqat tanlangan hududlar olinadi;
///   • ro'yxat [CallerIdIos.parts] ta teng bo'lakka bo'linib, har bir
///     bo'lakni alohida extension yuklaydi.
class RegionCallerId {
  RegionCallerId._();

  static const regions = <CallerRegion>[
    CallerRegion('andijon', 'Andijon',
        ['andijon', 'andijan', 'andizhan', 'ндижон', 'ндижан']),
    CallerRegion('buxoro', 'Buxoro',
        ['buxor', 'buxar', 'bukhar', 'buhar', 'ухар', 'ухор']),
    CallerRegion('fargona', "Farg'ona", [
      "farg'on", 'fargʻon', 'fargʼon', 'farg`on', 'fargon', 'farghon',
      'fergan', 'арғон', 'аргон', 'ерган',
    ]),
    // Jizzax: avvalgi versiyadagi shartlar aynan saqlangan
    CallerRegion('jizzax', 'Jizzax',
        ['jizza', 'jizak', 'djiza', 'dzhiza', 'изза', 'жизак']),
    CallerRegion('xorazm', 'Xorazm', [
      'xorazm', 'xorezm', 'khorazm', 'khorezm', 'horezm', 'оразм', 'орезм',
    ]),
    CallerRegion('namangan', 'Namangan', ['namangan', 'аманган']),
    CallerRegion('navoiy', 'Navoiy', ['navoi', 'navoy', 'авои']),
    CallerRegion('qashqadaryo', 'Qashqadaryo',
        ['qashqadar', 'kashkadar', 'ашқадар', 'ашкадар']),
    CallerRegion('qoraqalpogiston', "Qoraqalpog'iston", [
      'qoraqalpo', 'qaraqalpa', 'karakalpa', 'nukus',
      'орақалпо', 'оракалпо', 'аракалпа', 'укус', // Нукус
    ]),
    CallerRegion('samarqand', 'Samarqand',
        ['samarq', 'samark', 'амарқ', 'амарк']),
    CallerRegion('sirdaryo', 'Sirdaryo',
        ['sirdar', 'syrdar', 'ирдар', 'ырдар']),
    CallerRegion('surxondaryo', 'Surxondaryo', [
      'surxondar', 'surxandar', 'surkhondar', 'surkhandar',
      'урхондар', 'урхандар',
    ]),
    CallerRegion('toshkent_vil', 'Toshkent viloyati', _toshkent,
        requireAny: _viloyatMarkers),
    CallerRegion('toshkent_sh', 'Toshkent shahri', _toshkent,
        exclude: _viloyatMarkers),
  ];

  /// N-bo'lak fayli. Nomlar CallDirectoryHandler.swift dagi bilan bir xil;
  /// 1-bo'lak eski versiyadagi nomini saqlaydi.
  static String fileFor(int part) =>
      part == 1 ? 'callerid.bin' : 'callerid_$part.bin';

  /// Bitta bo'lakka taxminiy chegara. Undan oshsa ogohlantiramiz
  /// (iOS baribir urinib ko'radi).
  static const softLimitPerPart = 1500000;
  static int get softLimit => softLimitPerPart * CallerIdIos.parts;

  static const _chunk = 250000; // bir so'rovda ko'riladigan qatorlar (rowid)
  static const _maxLabel = 60;

  // Kalit nomlari eski versiya bilan bir xil — avval tayyorlangan ro'yxat
  // haqidagi ma'lumot yo'qolmasin
  static const _kCount = 'jizzax_cid_count';
  static const _kTime = 'jizzax_cid_time';
  static const _kSelected = 'cid_regions';
  static const _kBuilt = 'cid_built_regions';

  static const defaultSelection = ['jizzax'];

  static CallerRegion? byId(String id) {
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  static String names(Iterable<String> ids) =>
      ids.map((i) => byId(i)?.name ?? i).join(', ');

  /// Foydalanuvchi tanlagan hududlar
  static Future<List<String>> selected() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getStringList(_kSelected);
    final ok = (v ?? defaultSelection).where((i) => byId(i) != null).toList();
    return ok.isEmpty ? List.of(defaultSelection) : ok;
  }

  static Future<void> setSelected(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSelected, ids);
  }

  /// Oxirgi tayyorlangan ro'yxat: (raqamlar soni, vaqt, hududlar) yoki null.
  /// Eski versiyada hudud saqlanmagan — u faqat Jizzax edi.
  static Future<(int, DateTime, List<String>)?> lastBuild() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getInt(_kCount);
    final t = p.getInt(_kTime);
    if (n == null || t == null) return null;
    final built = p.getStringList(_kBuilt) ?? defaultSelection;
    return (n, DateTime.fromMillisecondsSinceEpoch(t), built);
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

  /// So'zlardan LIKE andozalari: kirill bo'lsa KATTA varianti ham qo'shiladi.
  static List<String> _patterns(List<String> words) {
    final out = <String>{};
    for (final w in words) {
      out.add('%$w%');
      final up = w.toUpperCase();
      if (up != w && w.codeUnits.any((c) => c > 127)) out.add('%$up%');
    }
    return out.toList();
  }

  /// Tanlangan hududlar uchun WHERE sharti va uning parametrlari.
  static (String, List<String>) _where(List<String> ids) {
    final parts = <String>[];
    final args = <String>[];

    String any(List<String> pats) {
      args.addAll(pats);
      return pats.map((_) => '"adres" LIKE ?').join(' OR ');
    }

    for (final id in ids) {
      final r = byId(id);
      if (r == null) continue;
      var cond = '(${any(_patterns(r.stems))})';
      if (r.requireAny.isNotEmpty) {
        cond += ' AND (${any(_patterns(r.requireAny))})';
      }
      if (r.exclude.isNotEmpty) {
        cond += ' AND NOT (${any(_patterns(r.exclude))})';
      }
      parts.add('($cond)');
    }
    return (parts.join(' OR '), args);
  }

  /// Ro'yxatni tayyorlab, extension'larni qayta yuklaydi.
  ///
  /// [onProgress] — (0..1 ulush, topilgan raqamlar soni, bosqich matni).
  /// Qaytaradi: raqamlar soni va Sozlamalarda o'chirilgan bo'laklar.
  /// Xatoda [CallerIdException].
  static Future<BuildResult> build(
      List<String> regionIds,
      void Function(double, int, String) onProgress) async {
    if (regionIds.isEmpty) {
      throw const CallerIdException("Kamida bitta hududni tanlang");
    }

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

    final (where, args) = _where(regionIds);
    final sql = 'SELECT "telefon", "abonent" FROM "$kTable" '
        'WHERE rowid > ? AND rowid <= ? AND ($where)';

    // Bir raqam bir necha marta uchrasa — birinchi topilgan ism qoladi
    final found = <int, String>{};

    await CallerIdIos.keepAwake(true);
    try {
      for (var lo = 0; lo < maxRow; lo += _chunk) {
        final rows = await db.rawQuery(sql, [lo, lo + _chunk, ...args]);
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
        throw CallerIdException(
            "Manzilida ${names(regionIds)} yozilgan raqam topilmadi");
      }

      // Saralab, teng bo'laklarga ajratamiz. Har bir bo'lak o'z ichida
      // o'sish tartibida qoladi — iOS shuni talab qiladi.
      final keys = found.keys.toList()..sort();
      final parts = CallerIdIos.parts;
      final size = (keys.length + parts - 1) ~/ parts;

      onProgress(0.91, found.length, 'Fayllar yozilmoqda');
      for (var part = 1; part <= parts; part++) {
        final from = ((part - 1) * size).clamp(0, keys.length);
        final to = (part * size).clamp(0, keys.length);
        await _writeFile('$container/${fileFor(part)}',
            keys.sublist(from, to), found);
      }

      final disabled = <int>[];
      for (var part = 1; part <= parts; part++) {
        onProgress(0.93 + 0.07 * (part - 1) / parts, found.length,
            "iOS'ga yuklanmoqda ($part/$parts)");
        final r = await CallerIdIos.reload(part);
        if (r.ok) continue;
        if (r.disabled) {
          disabled.add(part);
          continue;
        }
        throw CallerIdException("Getcontact $part: ${r.message ?? 'xato'}");
      }

      final p = await SharedPreferences.getInstance();
      await p.setInt(_kCount, found.length);
      await p.setInt(_kTime, DateTime.now().millisecondsSinceEpoch);
      await p.setStringList(_kBuilt, regionIds);

      onProgress(1, found.length, 'Tayyor');
      return BuildResult(found.length, disabled);
    } finally {
      await CallerIdIos.keepAwake(false);
    }
  }

  /// Ro'yxatni o'chiradi (bo'sh fayllar) va extension'larni qayta yuklaydi.
  /// Qaytaradi: xato matni yoki null.
  static Future<String?> clear() async {
    final container = await CallerIdIos.containerPath();
    if (container != null) {
      for (var part = 1; part <= CallerIdIos.parts; part++) {
        await _writeFile('$container/${fileFor(part)}', const [], const {});
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCount);
    await p.remove(_kTime);
    await p.remove(_kBuilt);

    for (var part = 1; part <= CallerIdIos.parts; part++) {
      final r = await CallerIdIos.reload(part);
      // O'chirilgan extension'ni yangilab bo'lmaydi, lekin u yoqilganda
      // bo'sh faylni o'qiydi — ya'ni bu ham xato emas
      if (!r.ok && !r.disabled) return "Getcontact $part: ${r.message}";
    }
    return null;
  }

  /// Format CallDirectoryHandler.swift dagi bilan aynan bir xil:
  ///   "GCCD" | u32 versiya=1 | u32 N | i64[N] raqamlar |
  ///   u32[N+1] ism boshlanishlari | UTF-8 ismlar
  ///
  /// [keys] — shu faylga tushadigan raqamlar, o'sish tartibida.
  static Future<void> _writeFile(
      String path, List<int> keys, Map<int, String> data) async {
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

class BuildResult {
  /// Ro'yxatdagi raqamlar soni
  final int count;

  /// Sozlamalarda o'chirilgan bo'laklar (1…parts) — ulardagi raqamlarda
  /// ism chiqmaydi, toki foydalanuvchi ularni yoqmaguncha
  final List<int> disabledParts;

  const BuildResult(this.count, this.disabledParts);
}

class CallerIdException implements Exception {
  final String message;
  const CallerIdException(this.message);
  @override
  String toString() => message;
}
