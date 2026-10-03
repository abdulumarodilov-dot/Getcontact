import 'package:flutter/material.dart';
import '../theme.dart';
import 'common.dart';

/// Baza parolini so'raydigan oyna.
/// Bekor qilinsa `null`, aks holda kiritilgan parol qaytadi
/// (bo'sh satr = shifrlanmagan baza).
///
/// DIQQAT: bu oynaga Face ID / barmoq izi qo'yish ma'nosiz. Oyna faqat
/// saqlangan kalit YO'Q yoki NOTO'G'RI bo'lganda chiqadi — `DbService.open()`
/// saqlangan kalitni o'zi sinab ko'rgan bo'ladi. Biometrika bera oladigan
/// yangi kalit yo'q. Biometrika ilova qulfida (LockScreen) ishlaydi.
Future<String?> askDbPassword(
  BuildContext context, {
  String title = 'Baza paroli',
  String? message,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DbPasswordDialog(
      title: title,
      message: message,
      allowEmpty: allowEmpty,
    ),
  );
}

class _DbPasswordDialog extends StatefulWidget {
  final String title;
  final String? message;
  final bool allowEmpty;

  const _DbPasswordDialog({
    required this.title,
    this.message,
    required this.allowEmpty,
  });

  @override
  State<_DbPasswordDialog> createState() => _DbPasswordDialogState();
}

class _DbPasswordDialogState extends State<_DbPasswordDialog> {
  final _ctrl = TextEditingController();
  String _err = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text;
    if (v.isEmpty && !widget.allowEmpty) {
      setState(() => _err = "Parol bo'sh bo'lmasin");
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F529E), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 22, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.message!,
                style: const TextStyle(
                  color: AppColors.labelBlue,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            DarkInput(
              controller: _ctrl,
              hint: widget.allowEmpty
                  ? "Parol (shifrlanmagan bo'lsa — bo'sh)"
                  : 'Baza paroli',
              obscure: true,
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_err.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _err,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GhostBtn(
                    text: 'Bekor',
                    onTap: () => Navigator.pop(context, null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryBtn(
                    text: 'Ochish',
                    height: 50,
                    onTap: _submit,
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
