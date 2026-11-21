import 'package:callerid_ios/callerid_ios.dart';
import 'package:flutter/material.dart';

import '../services/region_callerid.dart';
import '../theme.dart';
import 'common.dart';

/// Sozlamalardagi «Qo'ng'iroqda ko'rsatish» bo'limi — faqat iPhone.
///
/// Tanlangan hududlar abonentlarining ro'yxatini tayyorlaydi; iOS kiruvchi
/// qo'ng'iroqda raqam ostida ismni o'zi ko'rsatadi. Ro'yxat
/// [CallerIdIos.parts] ta extension'ga bo'lingan — Sozlamalarda ularning
/// hammasi yoqilishi kerak.
class IosCallerIdPanel extends StatefulWidget {
  const IosCallerIdPanel({super.key});

  @override
  State<IosCallerIdPanel> createState() => _IosCallerIdPanelState();
}

class _IosCallerIdPanelState extends State<IosCallerIdPanel>
    with WidgetsBindingObserver {
  bool _loaded = false;
  bool _container = false;

  int _parts = CallerIdIos.parts;
  int _enabledCount = 0;
  List<String> _states = const [];

  (int, DateTime, List<String>)? _last;

  /// Foydalanuvchi tanlagan hududlar (hali tayyorlanmagan bo'lishi mumkin)
  List<String> _selected = List.of(RegionCallerId.defaultSelection);

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
      final last = await RegionCallerId.lastBuild();
      final sel = await RegionCallerId.selected();
      if (!mounted) return;
      setState(() {
        _container = s['container'] == true;
        _parts = (s['parts'] as int?) ?? CallerIdIos.parts;
        _enabledCount = (s['enabledCount'] as int?) ?? 0;
        _states = ((s['states'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        _last = last;
        _selected = sel;
        _loaded = true;
      });
    } catch (e) {
      // Eski IPA'da native qism yo'q — bo'lim ko'rsatilmaydi
      debugPrint('callerid_ios status: $e');
    }
  }

  /// Sozlamalarda yoqilmagan bo'laklar raqamlari (1…parts)
  List<int> get _disabledParts => [
        for (var i = 0; i < _states.length; i++)
          if (_states[i] != 'enabled') i + 1,
      ];

  static String _partNames(List<int> parts) =>
      parts.map((p) => 'Getcontact $p').join(', ');

  Future<void> _build() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _found = 0;
      _stage = 'Boshlanmoqda';
      _msg = '';
    });

    try {
      final r = await RegionCallerId.build(_selected, (p, found, stage) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _found = found;
          _stage = stage;
        });
      });
      if (!mounted) return;

      final b = StringBuffer("Tayyor: ${_fmt(r.count)} ta raqam, "
          "$_parts bo'lakka bo'lindi.");
      if (r.disabledParts.isNotEmpty) {
        b.write(" ${_partNames(r.disabledParts)} Sozlamalarda yoqilmagan — "
            "ularni yoqing, aks holda ro'yxatning o'sha qismida ism "
            "chiqmaydi.");
      } else if (r.count > RegionCallerId.softLimit) {
        b.write(" Bu iOS chegarasiga yaqin — qo'ng'iroqda ism chiqmasa, "
            "menga ayting.");
      }
      setState(() {
        _msgError = r.disabledParts.isNotEmpty;
        _msg = b.toString();
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
    final err = await RegionCallerId.clear();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msgError = err != null;
      _msg = err ?? "Ro'yxat o'chirildi";
    });
    await _refresh();
  }

  /// Viloyatlar ro'yxati — alohida oynada, panelni to'ldirib yubormasin
  Future<void> _pickRegions() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegionSheet(initial: _selected),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected = picked;
      _msg = '';
    });
    await RegionCallerId.setSelected(picked);
  }

  /// Tanlov oxirgi tayyorlangan ro'yxatdan farq qiladimi
  bool get _selectionChanged {
    final last = _last;
    if (last == null) return false;
    final a = {...last.$3};
    final b = {..._selected};
    return a.length != b.length || !a.containsAll(b);
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

    final allEnabled = _enabledCount >= _parts;
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
            "Tanlangan viloyatlardagi abonentlar qo'ng'iroq qilganda, "
            "iPhone raqam ostida ismni o'zi ko'rsatadi. Ro'yxat telefonda "
            "qoladi, internetga chiqmaydi.",
            style: TextStyle(
              color: AppColors.labelBlue,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          // ── Viloyatlar: bitta tugma, ro'yxat alohida oynada ──
          Material(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : _pickRegions,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inputBorder, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined,
                        size: 20, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Viloyatlar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            RegionCallerId.names(_selected),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.labelBlue,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 22, color: AppColors.accent),
                  ],
                ),
              ),
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
            allEnabled,
            allEnabled
                ? 'Sozlamalarda yoqilgan: $_enabledCount/$_parts'
                : "Sozlamalarda yoqilgan: $_enabledCount/$_parts. "
                    "Yoqing: ${_partNames(_disabledParts)}\n"
                    "Настройки → Приложения → Телефон → Блокировка и "
                    "идентификация вызовов",
          ),
          _row(
            last != null,
            last != null
                ? "Ro'yxat: ${RegionCallerId.names(last.$3)} — "
                    "${_fmt(last.$1)} ta raqam (${_date(last.$2)})"
                : "Ro'yxat hali tayyorlanmagan",
          ),
          if (_selectionChanged && !_busy)
            const Text(
              "Viloyatlar o'zgardi — yangi ro'yxat uchun «Ro'yxatni "
              "yangilash» ni bosing.",
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                height: 1.35,
              ),
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
            if (!allEnabled)
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

/// Viloyatlarni tanlash oynasi. Natija — tanlangan id'lar
/// (bekor qilinsa null). Kamida bitta viloyat tanlangan bo'lishi shart.
class _RegionSheet extends StatefulWidget {
  final List<String> initial;
  const _RegionSheet({required this.initial});

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  late final Set<String> _sel = {...widget.initial};

  void _toggle(String id) {
    setState(() {
      if (_sel.contains(id)) {
        if (_sel.length > 1) _sel.remove(id); // kamida bittasi qolsin
      } else {
        _sel.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    // Ro'yxatdagi tartibda qaytaramiz — matnda ham shu tartibda chiqadi
    final ordered = [
      for (final r in RegionCallerId.regions)
        if (_sel.contains(r.id)) r.id,
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F529E), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Viloyatlar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Ro'yxat 4 bo'lakka bo'linadi, har biriga taxminan "
              "1,5 mln raqam sig'adi. Bir nechta katta viloyatni birga "
              "tanlasangiz, chegaradan oshishi mumkin.",
              style: TextStyle(
                color: AppColors.hint,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in RegionCallerId.regions)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _toggle(r.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 11, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                _sel.contains(r.id)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 22,
                                color: _sel.contains(r.id)
                                    ? AppColors.accent
                                    : AppColors.hint,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                r.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GhostBtn(
                    text: 'Bekor',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryBtn(
                    text: 'Tayyor',
                    height: 50,
                    onTap: () => Navigator.pop(context, ordered),
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
