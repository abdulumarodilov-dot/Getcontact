import 'package:callerid_ios/callerid_ios.dart';
import 'package:flutter/material.dart';

import '../services/jizzax_callerid.dart';
import '../theme.dart';
import 'common.dart';

/// Sozlamalardagi «Qo'ng'iroqda ko'rsatish» bo'limi — faqat iPhone.
///
/// Jizzax viloyati abonentlarining ro'yxatini tayyorlaydi; iOS kiruvchi
/// qo'ng'iroqda raqam ostida ismni o'zi ko'rsatadi.
class IosCallerIdPanel extends StatefulWidget {
  const IosCallerIdPanel({super.key});

  @override
  State<IosCallerIdPanel> createState() => _IosCallerIdPanelState();
}

class _IosCallerIdPanelState extends State<IosCallerIdPanel>
    with WidgetsBindingObserver {
  bool _loaded = false;
  bool _container = false;
  String _enabled = 'unknown'; // enabled | disabled | unknown
  (int, DateTime)? _last;

  bool _busy = false;
  double _progress = 0;
  int _found = 0;
  String _stage = '';

  String _msg = '';
  bool _msgError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foydalanuvchi Sozlamalardan qaytganda holatni yangilaymiz
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await CallerIdIos.status();
      final last = await JizzaxCallerId.lastBuild();
      if (!mounted) return;
      setState(() {
        _container = s['container'] == true;
        _enabled = (s['enabled'] ?? 'unknown').toString();
        _last = last;
        _loaded = true;
      });
    } catch (e) {
      // Eski IPA'da native qism yo'q — bo'lim ko'rsatilmaydi
      debugPrint('callerid_ios status: $e');
    }
  }

  Future<void> _build() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _found = 0;
      _stage = 'Boshlanmoqda';
      _msg = '';
    });

    try {
      final n = await JizzaxCallerId.build((p, found, stage) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _found = found;
          _stage = stage;
        });
      });
      if (!mounted) return;
      setState(() {
        _msgError = false;
        _msg = n > JizzaxCallerId.softLimit
            ? "Yuklandi: ${_fmt(n)} ta raqam. Bu iOS chegarasiga yaqin — "
                "qo'ng'iroqda ism chiqmasa, menga ayting."
            : "Tayyor: ${_fmt(n)} ta raqam yuklandi.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgError = true;
        _msg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final err = await JizzaxCallerId.clear();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msgError = err != null;
      _msg = err ?? "Ro'yxat o'chirildi";
    });
    await _refresh();
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _row(bool ok, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? AppColors.success : AppColors.hint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: ok ? AppColors.success : AppColors.hint,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final enabled = _enabled == 'enabled';
    final last = _last;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        spacing: 10,
        children: [
          const Text(
            "Qo'ng'iroqda ko'rsatish",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Manzili Jizzax viloyati bo'lgan abonentlar qo'ng'iroq "
            "qilganda, iPhone raqam ostida ismni o'zi ko'rsatadi. "
            "Ro'yxat telefonda qoladi, internetga chiqmaydi.",
            style: TextStyle(
              color: AppColors.labelBlue,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          _row(
            _container,
            _container
                ? 'Umumiy papka ishlayapti'
                : "Umumiy papka (App Group) yo'q — ilovani AltStore "
                    "yoki SideStore orqali o'rnating",
          ),
          _row(
            enabled,
            enabled
                ? 'Sozlamalarda yoqilgan'
                : "Sozlamalarda yoqilmagan: Настройки → Приложения → "
                    "Телефон → Блокировка и идентификация вызовов → "
                    "Getcontact",
          ),
          _row(
            last != null,
            last != null
                ? "Ro'yxat: ${_fmt(last.$1)} ta raqam (${_date(last.$2)})"
                : "Ro'yxat hali tayyorlanmagan",
          ),
          if (_busy) ...[
            LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: AppColors.inputBg,
              color: AppColors.accent,
            ),
            Text(
              "$_stage… ${(_progress * 100).round()}% · "
              "${_fmt(_found)} ta raqam\n"
              "Ilovani yopmang — bir necha daqiqa davom etadi.",
              style: const TextStyle(
                color: AppColors.labelBlue,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (_msg.isNotEmpty && !_busy)
            Text(
              _msg,
              style: TextStyle(
                color: _msgError ? AppColors.error : AppColors.accent,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          if (!_busy) ...[
            PrimaryBtn(
              text: last == null
                  ? "Ro'yxatni tayyorlash"
                  : "Ro'yxatni yangilash",
              height: 50,
              onTap: _container ? _build : null,
            ),
            if (!enabled)
              SizedBox(
                width: double.infinity,
                child: GhostBtn(
                  text: 'Sozlamalarni ochish',
                  onTap: () async {
                    final ok = await CallerIdIos.openSettings();
                    if (!ok && mounted) {
                      setState(() {
                        _msgError = false;
                        _msg = "Настройки → Приложения → Телефон → "
                            "Блокировка и идентификация вызовов";
                      });
                    }
                  },
                ),
              ),
            if (last != null)
              SizedBox(
                width: double.infinity,
                child: GhostBtn(
                  text: "Ro'yxatni o'chirish",
                  onTap: _clear,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
