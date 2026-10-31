import 'package:flutter/foundation.dart';
import 'package:quick_link_ios/quick_link_ios.dart';

/// Tashqaridan kelgan qidiruv so'rovi.
///
/// `values` — bir xil qiymatning bir nechta ko'rinishi (masalan telefon
/// uchun "901234567" va "998901234567"). Qidiruv ekrani ularni navbat
/// bilan sinab ko'radi va birinchi natija topilganda to'xtaydi.
class QuickSearchRequest {
  final String column;
  final List<String> values;
  const QuickSearchRequest(this.column, this.values);

  @override
  String toString() => 'QuickSearchRequest($column, $values)';
}

/// iPhone'dagi Action Button / Shortcuts orqali tezkor qidiruv.
///
/// Shortcut ilovani shunday havola bilan ochadi:
///
///     getcontact://search?q=+998 90 123-45-67
///
/// Havola kelganda so'rov `pending` ga yoziladi. Qidiruv ekrani
/// (SearchScreen) uni o'zi oladi. Ilova qulflangan bo'lsa, SearchScreen
/// faqat Face ID / parol o'tgandan keyin yaratiladi — demak so'rov ham
/// faqat qulf ochilgandan keyin bajariladi.
class QuickSearchLink {
  QuickSearchLink._();
  static final QuickSearchLink instance = QuickSearchLink._();

  /// Bajarilishini kutayotgan so'rov (bo'lmasa null).
  final ValueNotifier<QuickSearchRequest?> pending =
      ValueNotifier<QuickSearchRequest?>(null);

  bool _started = false;

  // Bitta havola qisqa vaqtda ikki marta kelishi mumkin.
  String? _lastRaw;
  DateTime? _lastAt;

  /// main() da bir marta chaqiriladi.
  ///
  /// Havolalarni o'zimizning native plagin (quick_link_ios) qabul qiladi:
  /// Flutter 3.38+ UIScene shablonida ilova yopiq holatdan havola bilan
  /// ochilganda app_links paketi havolani yo'qotar edi.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    await QuickLinkIos.listen(_handle);
  }

  /// So'rovni oladi va navbatdan o'chiradi.
  QuickSearchRequest? take() {
    final r = pending.value;
    if (r != null) pending.value = null;
    return r;
  }

  void _handle(Uri uri) {
    if (uri.scheme.toLowerCase() != 'getcontact') return;

    // getcontact://search?q=...  (host = search)
    // getcontact:///search?q=... (path = /search)
    final isSearch = uri.host.toLowerCase() == 'search' ||
        uri.path.toLowerCase() == '/search';
    if (!isSearch) return;

    final raw = (uri.queryParameters['q'] ?? '').trim();
    if (raw.isEmpty) return;

    final now = DateTime.now();
    if (raw == _lastRaw &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastRaw = raw;
    _lastAt = now;

    final req = parse(raw);
    if (req != null) pending.value = req;
  }

  /// Matnga qarab qaysi ustundan qidirishni aniqlaydi.
  ///
  ///   "+998 90 123-45-67" → telefon: 901234567, 998901234567
  ///   "90 123 45 67"      → telefon: 901234567, 998901234567
  ///   "32304217890123"    → jshshir (14 raqam)
  ///   "aa 1234567"        → pasport: AA1234567
  ///   "Aliyev Vali"       → abonent
  static QuickSearchRequest? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final compact = text.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

    // Pasport: 2 harf + 7 raqam
    if (RegExp(r'^[A-Z]{2}\d{7}$').hasMatch(compact)) {
      return QuickSearchRequest('pasport', [compact]);
    }

    // Harf bor — ism-familiya
    if (RegExp(r'[A-Za-zА-Яа-яЁёЎўҚқҒғҲҳ]').hasMatch(text)) {
      return QuickSearchRequest('abonent', [text]);
    }

    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // JShShIR — 14 raqam (00998... ko'rinishidagi telefon ham 14 raqam,
    // lekin u 00998 bilan boshlanadi)
    if (digits.length == 14 && !digits.startsWith('00998')) {
      return QuickSearchRequest('jshshir', [digits]);
    }

    // Telefon: bazada asosan 9 raqamli ko'rinishda saqlanadi,
    // ehtiyot uchun 998 bilan ham sinab ko'ramiz.
    String? local;
    if (digits.length == 9) {
      local = digits;
    } else if (digits.length == 12 && digits.startsWith('998')) {
      local = digits.substring(3);
    } else if (digits.length == 14 && digits.startsWith('00998')) {
      local = digits.substring(5);
    } else if (digits.length == 10 && digits.startsWith('8')) {
      local = digits.substring(1); // eski format: 8 90 123 45 67
    }

    if (local != null) {
      return QuickSearchRequest('telefon', [local, '998$local']);
    }
    return QuickSearchRequest('telefon', [digits]);
  }
}
