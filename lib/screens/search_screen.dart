import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/field_meta.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';
import '../widgets/db_password_dialog.dart';
import '../widgets/result_card.dart';
import 'settings_screen.dart';

const int kMinChars = 1;
const int kMinCharsName = 2; // abonent uchun — LIKE qidiruv kengroq
const Duration kDebounce = Duration(milliseconds: 300);
const Duration kDebounceeName = Duration(milliseconds: 400);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  String _column = 'telefon';
  String _status = '';
  bool _isError = false;
  bool _locked = false; // baza shifrlangan, parol kerak
  List<DbRecord> _results = [];

  Timer? _debounce;
  int _seq = 0; // eskirgan natijalarni tashlab yuborish uchun

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDb());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  SearchColumn get _col =>
      searchColumns.firstWhere((c) => c.key == _column);

  Future<void> _openDb({bool promptForKey = true}) async {
    if (DbService.instance.isOpen) return;

    final res = await DbService.instance.open();
    if (!mounted) return;

    if (res.isOk) {
      setState(() {
        _status = '';
        _isError = false;
        _locked = false;
      });
      return;
    }

    final needsKey =
        res.state == DbState.needKey || res.state == DbState.wrongKey;

    setState(() {
      _status = res.message ?? 'Bazani ochib bo\'lmadi';
      _isError = true;
      _locked = needsKey;
    });

    if (needsKey && promptForKey) await _askKey();
  }

  /// Baza parolini so'rab, ochishga urinadi
  Future<void> _askKey() async {
    final pass = await askDbPassword(
      context,
      message: 'Baza AES bilan shifrlangan. Parol qurilmaning xavfsiz '
          'xotirasida saqlanadi — keyingi safar so\'ralmaydi.',
    );
    if (pass == null || !mounted) return;

    setState(() {
      _status = 'Ochilmoqda...';
      _isError = false;
    });

    final res = await DbService.instance.unlock(pass);
    if (!mounted) return;

    setState(() {
      if (res.isOk) {
        // ok bo'lsa ham xabar bo'lishi mumkin — masalan kalit saqlanmadi
        _status = res.message ?? '';
        _isError = false;
        _locked = false;
      } else {
        _status = res.message ?? "Parol noto'g'ri";
        _isError = true;
        _locked = true;
      }
    });

    if (res.isOk && _query.text.trim().isNotEmpty) _search();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final q = _query.text.trim();

    final minChars = _column == 'abonent' ? kMinCharsName : kMinChars;
    if (q.length < minChars) {
      _seq++;
      setState(() {
        _results = [];
        if (DbService.instance.isOpen) {
          _status = '';
          _isError = false;
        }
      });
      return;
    }

    // Tozalash tugmasi darhol ko'rinishi uchun
    setState(() {});
    final delay = _column == 'abonent' ? kDebounceeName : kDebounce;
    _debounce = Timer(delay, _search);
  }

  Future<void> _search() async {
    if (!DbService.instance.isOpen) {
      await _openDb();
      if (!mounted) return;
      if (!DbService.instance.isOpen) return;
    }

    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _status = '';
        _isError = false;
      });
      return;
    }

    _seq++;
    final seq = _seq;
    final col = _column;

    setState(() {
      _status = 'Qidirilmoqda...';
      _isError = false;
    });

    try {
      final rows = await DbService.instance.search(col, q);
      if (!mounted || seq != _seq) return; // eskirgan natija

      setState(() {
        _results = rows;
        _isError = false;
        if (rows.isEmpty) {
          _status = 'Natija topilmadi';
        } else {
          final suffix = rows.length >= kMaxResults ? '+' : '';
          _status = 'Natijalar: ${rows.length}$suffix ta';
        }
      });

      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _status = 'Xato: $e';
        _isError = true;
        _results = [];
      });
    }
  }

  void _setColumn(String key) {
    setState(() => _column = key);
    if (_query.text.trim().isNotEmpty) _search();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (!mounted) return;
    // Sozlamalarda baza import qilingan yoki kalit o'chirilgan bo'lishi mumkin
    if (DbService.instance.isOpen) {
      if (_isError || _locked) {
        setState(() {
          _status = '';
          _isError = false;
          _locked = false;
        });
      }
    } else {
      setState(() => _results = []);
      await _openDb(promptForKey: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sarlavha ────────────────────────────────
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Ma'lumotlar qidiruvi",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SettingsPill(onTap: _openSettings),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Ustun tanlash chiplari ──────────────────
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: searchColumns.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = searchColumns[i];
                      return _ColumnChip(
                        column: c,
                        selected: c.key == _column,
                        onTap: () => _setColumn(c.key),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Qidiruv maydoni ─────────────────────────
                Container(
                  height: 56,
                  padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _focus.hasFocus
                          ? AppColors.inputBorderFocus
                          : AppColors.inputBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 24, color: Color(0xFF7AB8FF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          focusNode: _focus,
                          onSubmitted: (_) => _search(),
                          textInputAction: TextInputAction.search,
                          keyboardType: _column == 'telefon' ||
                                  _column == 'jshshir'
                              ? TextInputType.number
                              : TextInputType.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                          cursorColor: AppColors.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: _col.example,
                            hintStyle: const TextStyle(
                              color: AppColors.hint,
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      if (_query.text.isNotEmpty)
                        CircleBtn(
                          icon: Icons.close,
                          size: 32,
                          filled: false,
                          iconColor: AppColors.hint,
                          onTap: () => _query.clear(),
                        ),
                    ],
                  ),
                ),

                // ── Holat matni ─────────────────────────────
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    style: TextStyle(
                      color: _isError ? AppColors.error : AppColors.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),
                ],

                // ── Qulflangan baza uchun tugma ─────────────
                if (_locked) ...[
                  const SizedBox(height: 12),
                  GhostBtn(
                    text: 'Baza parolini kiritish',
                    onTap: _askKey,
                  ),
                ],
                const SizedBox(height: 10),

                // ── Natijalar ───────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => ResultCard(record: _results[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ustun tanlash chipi (Kivy'dagi Chip)
class _ColumnChip extends StatelessWidget {
  final SearchColumn column;
  final bool selected;
  final VoidCallback onTap;

  const _ColumnChip({
    required this.column,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.accent;

    return Material(
      color: selected ? const Color(0xFF1F63D6) : AppColors.inputBg,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? const Color(0xFF3D82EE)
                  : AppColors.inputBorder,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(column.icon, size: 19, color: fg),
              const SizedBox(width: 7),
              Text(
                column.title,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
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
