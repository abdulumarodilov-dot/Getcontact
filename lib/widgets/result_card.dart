import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/field_meta.dart';
import '../services/db_service.dart';
import 'common.dart';

/// Bitta maydon qatori (Kivy'dagi FieldRow)
class FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Natija kartochkasi (Kivy'dagi ResultCard)
class ResultCard extends StatelessWidget {
  final DbRecord record;
  const ResultCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final rows = record.isEmpty
        ? [
            const FieldRow(
              label: '-',
              value: "(bo'sh)",
              icon: Icons.description_outlined,
            )
          ]
        : record.map((e) {
            final meta = fieldMeta(e.key);
            return FieldRow(
              label: meta.label,
              value: e.value,
              icon: meta.icon,
            );
          }).toList();

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
              children: rows,
            ),
          ),
          const SizedBox(width: 6),
          CircleBtn(
            icon: Icons.chevron_right,
            size: 46,
            onTap: () => showDetailSheet(context, record),
          ),
        ],
      ),
    );
  }
}

/// Batafsil ma'lumot oynasi (Kivy'dagi DetailView)
void showDetailSheet(BuildContext context, DbRecord record) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DetailSheet(record: record),
  );
}

class _DetailSheet extends StatefulWidget {
  final DbRecord record;
  const _DetailSheet({required this.record});

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
                  children: widget.record.map((e) {
                    final meta = fieldMeta(e.key);
                    return FieldRow(
                      label: meta.label,
                      value: e.value,
                      icon: meta.icon,
                    );
                  }).toList(),
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
