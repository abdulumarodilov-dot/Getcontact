import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
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

  bool _bioAvailable = false; // qurilmada biometrika bor va ro'yxatga olingan
  bool _bioOn = false; // foydalanuvchi yoqib qo'ygan
  bool _bioBusy = false; // tekshiruv ketmoqda
  String _bioLabel = 'Biometrika';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final setup = await AuthService.instance.isSetupMode();
    final avail = await BiometricService.instance.isAvailable();
    final on = await AuthService.instance.isBiometricEnabled();
    final label = avail ? await BiometricService.instance.label() : '';
    if (!mounted) return;
    setState(() {
      _setupMode = setup;
      _bioAvailable = avail;
      _bioOn = on;
      if (label.isNotEmpty) _bioLabel = label;
      _loading = false;
    });

    // Parol o'rnatilgan va biometrika yoqilgan bo'lsa — darhol so'raymiz,
    // foydalanuvchi tugmani qidirib yurmasin.
    if (!setup && avail && on) await _useBiometric(auto: true);
  }

  /// Biometrik tekshiruv. `auto` — ekran ochilishida o'zi ishga tushgan
  /// (bu holda bekor qilinsa xabar ko'rsatilmaydi, parol maydoni qoladi).
  Future<void> _useBiometric({bool auto = false}) async {
    if (_bioBusy) return;
    setState(() {
      _bioBusy = true;
      _msg = '';
    });

    final res = await BiometricService.instance
        .authenticate('Getcontact ilovasiga kirish');
    if (!mounted) return;

    if (res.ok) {
      _goSearch();
      return;
    }

    setState(() {
      _bioBusy = false;
      // res.message == null — foydalanuvchi o'zi bekor qilgan, janjal qilmaymiz
      _msg = (auto || res.message == null) ? '' : res.message!;
    });
  }

  /// Parol bilan muvaffaqiyatli kirgandan keyin bir marta taklif qiladi.
  Future<void> _offerBiometric() async {
    if (!_bioAvailable) return;
    // null bo'lsa — hali so'ralmagan; aks holda tanlov qilingan
    if (await AuthService.instance.biometricPref() != null) return;
    if (!mounted) return;

    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BioOfferDialog(label: _bioLabel),
    );
    if (!mounted) return;

    if (yes != true) {
      await AuthService.instance.setBiometricEnabled(false);
      return;
    }
    // Yoqishdan oldin bir marta tekshirib ko'ramiz — ishlamasa yoqmaymiz
    final res = await BiometricService.instance
        .authenticate("$_bioLabel ni yoqish uchun tasdiqlang");
    await AuthService.instance.setBiometricEnabled(res.ok);
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
      await _offerBiometric();
      _goSearch();
    } else {
      final ok = await AuthService.instance.verify(p1);
      if (!mounted) return;
      if (ok) {
        await _offerBiometric();
        if (!mounted) return;
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
                if (!_setupMode && _bioAvailable && _bioOn) ...[
                  const SizedBox(height: 14),
                  _BioButton(
                    label: _bioLabel,
                    busy: _bioBusy,
                    onTap: _bioBusy ? null : () => _useBiometric(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Face ID / Touch ID / barmoq izi tugmasi
class _BioButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _BioButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFace = label.contains('Face') || label.contains('Yuz');

    return Material(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inputBorder, width: 1.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Icon(
                  isFace ? Icons.face_retouching_natural : Icons.fingerprint,
                  size: 22,
                  color: AppColors.accent,
                ),
              const SizedBox(width: 10),
              Text(
                '$label bilan kirish',
                style: const TextStyle(
                  color: AppColors.accent,
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

/// "Keyingi safar biometrika bilan kirasizmi?" — bir marta so'raladi
class _BioOfferDialog extends StatelessWidget {
  final String label;

  const _BioOfferDialog({required this.label});

  @override
  Widget build(BuildContext context) {
    final isFace = label.contains('Face') || label.contains('Yuz');

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
                Icon(
                  isFace ? Icons.face_retouching_natural : Icons.fingerprint,
                  size: 22,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$label bilan kirish',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Keyingi safar parol yozmasdan $label bilan kirishni '
              "yoqamizmi? Parol zaxira yo'l sifatida qoladi.",
              style: const TextStyle(
                color: AppColors.labelBlue,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GhostBtn(
                    text: 'Keyinroq',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryBtn(
                    text: 'Yoqish',
                    height: 50,
                    onTap: () => Navigator.pop(context, true),
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
