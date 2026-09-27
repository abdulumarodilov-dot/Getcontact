import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'search_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();

  bool _setupMode = false;
  bool _loading = true;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final setup = await AuthService.instance.isSetupMode();
    if (!mounted) return;
    setState(() {
      _setupMode = setup;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p1 = _p1.text.trim();
    if (p1.isEmpty) {
      setState(() => _msg = "Parol bo'sh bo'lmasin");
      return;
    }

    if (_setupMode) {
      final p2 = _p2.text.trim();
      if (p1 != p2) {
        setState(() => _msg = 'Parollar mos kelmadi');
        return;
      }
      if (p1.length < 4) {
        setState(() => _msg = 'Kamida 4 belgi');
        return;
      }
      try {
        await AuthService.instance
            .saveHash(AuthService.instance.hashPass(p1));
      } catch (e) {
        if (!mounted) return;
        setState(() => _msg = 'Saqlashda xato: $e');
        return;
      }
      if (!mounted) return;
      _goSearch();
    } else {
      final ok = await AuthService.instance.verify(p1);
      if (!mounted) return;
      if (ok) {
        _goSearch();
      } else {
        setState(() {
          _msg = "Parol noto'g'ri";
          _p1.clear();
        });
      }
    }
  }

  void _goSearch() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SearchScreen(),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: GradientBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.iconBoxBg,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.iconBoxBorder,
                      width: 1.4,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 46,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _setupMode ? 'Parol o\'rnating' : 'Xush kelibsiz',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _setupMode
                      ? 'Ilovani himoyalash uchun parol yarating'
                      : 'Davom etish uchun parolingizni yozing',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                DarkInput(
                  controller: _p1,
                  hint: 'Parol',
                  obscure: true,
                  action: _setupMode
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (_) => _setupMode ? null : _submit(),
                ),
                if (_setupMode) ...[
                  const SizedBox(height: 14),
                  DarkInput(
                    controller: _p2,
                    hint: 'Parolni takrorlang',
                    obscure: true,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if (_msg.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryBtn(
                  text: _setupMode ? 'Saqlash va kirish' : 'Kirish',
                  onTap: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
