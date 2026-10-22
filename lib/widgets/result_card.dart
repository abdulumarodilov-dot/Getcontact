import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/field_meta.dart';
import '../services/contact_actions.dart';
import '../services/db_service.dart';
import 'common.dart';

/// Natijadagi maydon ustiga bosilganda chaqiriladi:
/// shu ustun bo'yicha shu qiymat qayta qidiriladi.
typedef SearchCallback = void Function(String column, String value);

/// Bitta maydon qatori (Kivy'dagi FieldRow)
///
/// `onTap` berilsa qator bosiladigan bo'ladi. Bunday qatorda
/// `SelectableText` ishlatilmaydi — u bosishni o'ziga olib qo'yadi,
/// shuning uchun uning o'rniga uzoq bosib nusxalash qo'yilgan.
class FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  /// O'ng chetdagi kichik belgi — qator bosiladiganini bildiradi
  final IconData? actionIcon;

  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.actionIcon,
  });

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: value));
      messenger.showSnackBar(
        SnackBar(
          content: Text('$label nusxalandi'),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: AppColors.cardBorder,
        ),
      );
    } catch (_) {/* nusxalash muhim emas — jim o'tamiz */}
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconBox(icon: icon, size: 40),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.labelBlue,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: onTap == null
              ? SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0x663D82EE),
                    decorationThickness: 1.5,
                  ),
                ),
        ),
        if (actionIcon != null) ...[
          const SizedBox(width: 6),
          Icon(actionIcon, size: 18, color: AppColors.accent),
        ],
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _copy(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

/// Bitta yozuv uchun maydon qatorlarini yasaydi.
///
/// `onSearch` berilmasa qidiruv qatorlari oddiy matn bo'lib qoladi
/// (masalan qidiruv ekrani bo'lmagan joyda ishlatilsa).
List<Widget> buildFieldRows(
  BuildContext context,
  DbRecord record, {
  SearchCallback? onSearch,
}) {
  if (record.isEmpty) {
    return const [
      FieldRow(
        label: '-',
        value: "(bo'sh)",
        icon: Icons.description_outlined,
      ),
    ];
  }

  return record.map((e) {
    final meta = fieldMeta(e.key);
    final action = fieldAction(e.key);

    VoidCallback? tap;
    IconData? actionIcon;

    if (action.kind == FieldActionKind.call) {
      tap = () => showPhoneSheet(context, e.value);
      actionIcon = Icons.call;
    } else if (action.kind == FieldActionKind.search && onSearch != null) {
      // Ustun nomining o'zi qidiruv ustuni bo'lsa — aynan o'shani
      // ishlatamiz. Aks holda umumlashtirilgan nomga tushamiz
      // (masalan `pinfl` → `jshshir`).
      final key = e.key.trim().toLowerCase();
      final column =
          searchColumns.any((c) => c.key == key) ? key : action.column!;
      tap = () => onSearch(column, e.value);
      actionIcon = Icons.search;
    }

    return FieldRow(
      label: meta.label,
      value: e.value,
      icon: meta.icon,
      onTap: tap,
      actionIcon: actionIcon,
    );
  }).toList();
}

/// Natija kartochkasi (Kivy'dagi ResultCard)
class ResultCard extends StatelessWidget {
  final DbRecord record;

  /// JShShIR / Pasport ustiga bosilganda qayta qidirish
  final SearchCallback? onSearch;

  const ResultCard({super.key, required this.record, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buildFieldRows(context, record, onSearch: onSearch),
            ),
          ),
          const SizedBox(width: 6),
          CircleBtn(
            icon: Icons.chevron_right,
            size: 46,
            onTap: () =>
                showDetailSheet(context, record, onSearch: onSearch),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Telefon raqami uchun tanlov oynasi
// ──────────────────────────────────────────────────────────

void showPhoneSheet(BuildContext context, String phone) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PhoneSheet(phone: phone),
  );
}

class _PhoneSheet extends StatelessWidget {
  final String phone;
  const _PhoneSheet({required this.phone});

  /// Oynani yopib, keyin amalni bajaradi.
  ///
  /// `ScaffoldMessenger` oldindan olinadi — `Navigator.pop` dan keyin
  /// bu `context` yaroqsiz bo'lib qoladi va xatoni ko'rsatib bo'lmaydi.
  Future<void> _run(
    BuildContext context,
    Future<String?> Function(String) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    final err = await action(phone);
    if (err == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(err), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = ContactActions.normalizePhone(phone);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F529E), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shown.isEmpty ? phone : shown,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _SheetAction(
              icon: Icons.call,
              text: "Qo'ng'iroq qilish",
              onTap: () => _run(context, ContactActions.dial),
            ),
            _SheetAction(
              icon: Icons.sms_outlined,
              text: 'SMS yozish',
              onTap: () => _run(context, ContactActions.sms),
            ),
            _SheetAction(
              icon: Icons.copy_outlined,
              text: 'Nusxalash',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: phone));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Raqam nusxalandi'),
                    duration: Duration(milliseconds: 1200),
                    backgroundColor: AppColors.cardBorder,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: GhostBtn(
                text: 'Bekor',
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.accent),
              const SizedBox(width: 14),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Batafsil ma'lumot oynasi (Kivy'dagi DetailView)
// ──────────────────────────────────────────────────────────

void showDetailSheet(
  BuildContext context,
  DbRecord record, {
  SearchCallback? onSearch,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DetailSheet(record: record, onSearch: onSearch),
  );
}

class _DetailSheet extends StatefulWidget {
  final DbRecord record;
  final SearchCallback? onSearch;

  const _DetailSheet({required this.record, this.onSearch});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  String _copyLabel = 'Nusxalash';

  Future<void> _copyAll() async {
    final text = widget.record
        .map((e) => '${fieldMeta(e.key).label}: ${e.value}')
        .join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
      setState(() => _copyLabel = 'Nusxalandi');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _copyLabel = 'Nusxalash');
    } catch (_) {
      if (mounted) setState(() => _copyLabel = "Nusxalab bo'lmadi");
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    final onSearch = widget.onSearch;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F529E), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Batafsil ma'lumot",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: buildFieldRows(
                    context,
                    widget.record,
                    // Qidiruv boshlanishidan oldin bu oyna yopiladi,
                    // aks holda natijalar uning orqasida qolib ketadi.
                    onSearch: onSearch == null
                        ? null
                        : (column, value) {
                            Navigator.pop(context);
                            onSearch(column, value);
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: GhostBtn(text: _copyLabel, onTap: _copyAll)),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryBtn(
                    text: 'Yopish',
                    height: 50,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
