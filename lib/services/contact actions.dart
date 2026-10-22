import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Telefon raqami bilan ishlash: qo'ng'iroq va SMS.
///
/// Har bir metod muvaffaqiyatli bo'lsa `null`, aks holda foydalanuvchiga
/// ko'rsatiladigan xato matnini qaytaradi.
class ContactActions {
  ContactActions._();

  /// Bazadagi raqamni xalqaro ko'rinishga keltiradi.
  ///
  ///   "944069909"        → "+998944069909"   (mahalliy, 9 raqam)
  ///   "998944069909"     → "+998944069909"
  ///   "+998 94 406-99-09" → "+998944069909"
  ///
  /// Tanish shaklga tushmasa — raqamlar o'zgartirilmay qaytariladi,
  /// chunki noto'g'ri kod qo'shgandan ko'ra tegmagan yaxshi.
  static String normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 9) return '+998$digits';
    if (digits.length >= 11) return '+$digits';
    return digits;
  }

  /// Telefon ilovasini raqam terilgan holda ochadi
  static Future<String?> dial(String raw) => _open('tel', raw);

  /// SMS ilovasini raqam qo'yilgan holda ochadi
  static Future<String?> sms(String raw) => _open('sms', raw);

  static Future<String?> _open(String scheme, String raw) async {
    final number = normalizePhone(raw);
    if (number.isEmpty) return 'Raqam yaroqsiz';

    // Uri.parse — url_launcher hujjatidagi ko'rinish. Uri(path: ...) esa
    // "+" belgisini kodlab yuborishi mumkin edi.
    final uri = Uri.parse('$scheme:$number');
    try {
      final ok = await launchUrl(uri);
      if (ok) return null;
      return scheme == 'tel'
          ? "Qo'ng'iroqni boshlab bo'lmadi"
          : "SMS ilovasini ochib bo'lmadi";
    } catch (e) {
      debugPrint('$scheme ochishda xato: $e');
      // Planshet yoki simulyatorda telefon ilovasi umuman bo'lmasligi mumkin
      return 'Qurilmada mos ilova topilmadi';
    }
  }
}
