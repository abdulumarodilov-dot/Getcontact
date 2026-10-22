import 'package:flutter/material.dart';

/// Kivy'dagi FIELDS / FIELD_META mantiqining aynan ko'chirmasi
class FieldInfo {
  final String label;
  final IconData icon;
  const FieldInfo(this.label, this.icon);
}

/// Aniq mos keluvchi ustunlar
const Map<String, FieldInfo> _fields = {
  'abonent': FieldInfo("F.I.Sh.", Icons.person_outline),
  'telefon': FieldInfo('Telefon', Icons.phone_outlined),
  'adres': FieldInfo('Manzil', Icons.location_on_outlined),
  'pasport': FieldInfo('Pasport', Icons.description_outlined),
  'jshshir': FieldInfo('JShShIR', Icons.credit_card_outlined),
  'sana_1': FieldInfo('Sana 1', Icons.calendar_today_outlined),
  'sana_2': FieldInfo('Sana 2', Icons.calendar_today_outlined),
  'bergan_organ': FieldInfo('Bergan organ', Icons.description_outlined),
};

/// Noma'lum ustunlar uchun prefiks bo'yicha taxmin
const List<(String, String, IconData)> _prefixes = [
  ('abonent', "F.I.Sh.", Icons.person_outline),
  ('fio', "F.I.Sh.", Icons.person_outline),
  ('ism', 'Ism', Icons.person_outline),
  ('familiya', 'Familiya', Icons.person_outline),
  ('telefon', 'Telefon', Icons.phone_outlined),
  ('tel', 'Telefon', Icons.phone_outlined),
  ('manzil', 'Manzil', Icons.location_on_outlined),
  ('adres', 'Manzil', Icons.location_on_outlined),
  ('viloyat', 'Viloyat', Icons.location_on_outlined),
  ('tuman', 'Tuman', Icons.location_on_outlined),
  ('pasport', 'Pasport', Icons.description_outlined),
  ('seriya', 'Seriya', Icons.description_outlined),
  ('sana', 'Sana', Icons.calendar_today_outlined),
  ('tugilgan', "Tug'ilgan", Icons.calendar_today_outlined),
  ('jshshir', 'JShShIR', Icons.credit_card_outlined),
  ('pinfl', 'JShShIR', Icons.credit_card_outlined),
];

FieldInfo fieldMeta(String key) {
  final k = key.trim().toLowerCase();
  if (_fields.containsKey(k)) return _fields[k]!;

  final k2 = k.replaceAll("'", '');
  for (final (prefix, label, icon) in _prefixes) {
    if (k2.startsWith(prefix)) return FieldInfo(label, icon);
  }

  // Noma'lum: ustun nomini chiroyli ko'rinishga keltiramiz
  var pretty = key.trim().replaceAll('_', ' ');
  if (pretty.isNotEmpty) {
    pretty = pretty[0].toUpperCase() + pretty.substring(1);
  } else {
    pretty = '?';
  }
  return FieldInfo(pretty, Icons.description_outlined);
}

// ──────────────────────────────────────────────────────────
// Maydon ustiga bosilganda nima bo'ladi
// ──────────────────────────────────────────────────────────

enum FieldActionKind {
  /// Hech narsa — oddiy matn
  none,

  /// Telefon raqami — qo'ng'iroq / SMS
  call,

  /// Bu qiymat bo'yicha bazadan qayta qidirish
  search,
}

class FieldAction {
  final FieldActionKind kind;

  /// `search` uchun — qaysi ustundan qidiriladi.
  /// Faqat `searchColumns` dagi kalitlar bo'lishi mumkin.
  final String? column;

  const FieldAction(this.kind, [this.column]);

  static const none = FieldAction(FieldActionKind.none);
}

/// Ustun nomiga qarab bosish harakatini aniqlaydi.
///
/// Masalan `pinfl` ustuni ham JShShIR hisoblanadi va uning ustiga
/// bosilganda `jshshir` ustunidan qidiriladi.
FieldAction fieldAction(String key) {
  final k = key.trim().toLowerCase().replaceAll("'", '');

  if (k.startsWith('telefon') || k.startsWith('tel')) {
    return const FieldAction(FieldActionKind.call);
  }
  if (k.startsWith('jshshir') || k.startsWith('pinfl')) {
    return const FieldAction(FieldActionKind.search, 'jshshir');
  }
  // DIQQAT: "pasport_bergan_organ" kabi ustunlar pasport RAQAMI emas —
  // ular bo'yicha qidirish ma'nosiz, shuning uchun chetlab o'tamiz.
  if (k == 'pasport' || k == 'seriya' || k.startsWith('pasport_raqam')) {
    return const FieldAction(FieldActionKind.search, 'pasport');
  }
  return FieldAction.none;
}

/// Qidiruv ustunlari
class SearchColumn {
  final String key;
  final String title;
  final String example;
  final IconData icon;
  const SearchColumn(this.key, this.title, this.example, this.icon);
}

const List<SearchColumn> searchColumns = [
  SearchColumn('telefon', 'Telefon', '998901234567', Icons.phone_outlined),
  SearchColumn('abonent', 'Abonent', 'Ali Valiyev  •  %urb%nov', Icons.person_outline),
  SearchColumn('pasport', 'Pasport', 'AA1234567', Icons.description_outlined),
  SearchColumn('jshshir', 'JShShIR', '12345678901234', Icons.storage_outlined),
];
