import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';
import '../widgets/db_password_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// WidgetsBindingObserver — foydalanuvchi tizim sozlamalaridan qaytganda
// ruxsat holatini qayta o'qiymiz, aks holda ekran eski holatni ko'rsatadi.
class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _oldP = TextEditingController();
  final _newP = TextEditingController();
  final _confP = TextEditingController();

  String _pmsg = '';
  bool _pmsgError = true;

  String _dbMsg = '';
  bool _dbMsgError = true;
  bool _importing = false;
  bool _hasKey = false;

  bool _bioAvailable = false;
  bool _bioOn = false;
  String _bioLabel = 'Biometrika';

  // ── Qo'ng'iroqda ko'rsatish (faqat Android) ──────────────
  // Kotlin tomoni bilan aloqa. Nom MainActivity.kt dagi CHANNEL
  // bilan aynan bir xil bo'lishi shart.
  static const _cidChannel = MethodChannel('getcontact/callerid');

  bool _cidSupported = false; // Android 10+ va native qism bor
  bool _cidOverlay = false; // ekran ustida ko'rsatish ruxsati
  bool _cidRole = false; // qo'ng'iroqlarni tekshirish roli
  bool _cidDb = false; // baza yo'li va kaliti xizmatga berilgan
  String _cidMsg = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDbStatus();
    _refreshBio();
    _refreshCallerId();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ruxsat tizim sozlamalarida beriladi — qaytganda tekshiramiz
    if (state == AppLifecycleState.resumed) _refreshCallerId();
  }

  Future<void> _refreshCallerId() async {
    if (!Platform.isAndroid) return;
    try {
      final m = await _cidChannel.invokeMapMethod<String, dynamic>('status');
      if (!mounted || m == null) return;
      setState(() {
        _cidSupported = m['supported'] == true;
        _cidOverlay = m['overlay'] == true;
        _cidRole = m['role'] == true;
        _cidDb = m['db'] == true;
      });
    } catch (e) {
      // Eski APK'da native qism yo'q — bo'limni ko'rsatmaymiz
      debugPrint('callerid status: $e');
    }
  }

  Future<void> _cidRequest(String method) async {
    try {
      await _cidChannel.invokeMethod<void>(method);
    } catch (e) {
      debugPrint('callerid $method: $e');
    }
  }

  /// Baza yo'li va kalitini Kotlin tomoniga uzatadi — xizmat qo'ng'iroq
  /// paytida shular bilan bazani ochadi.
  Future<void> _cidSyncDb() async {
    final path = DbService.instance.path;
    if (path == null || path.isEmpty) {
      setState(() => _cidMsg =
          "Avval bazani oching: qidiruv ekraniga qaytib biror raqam qidiring");
      return;
    }

    // DIQQAT: kalit nomi db_service.dart dagi _keyName bilan aynan bir xil
    // bo'lishi shart — u yerda o'zgarsa, bu yer ham o'zgaradi.
    String? key;
    try {
      key = await const FlutterSecureStorage().read(key: 'royxat_db_key');
    } catch (e) {
      debugPrint("kalitni o'qishda: $e");
    }

    try {
      final ok = await _cidChannel.invokeMethod<bool>('saveDb', {
        'path': path,
        'key': key ?? '', // bo'sh = shifrlanmagan baza
      });
      if (!mounted) return;
      setState(() => _cidMsg = ok == true ? '' : "Bazani bog'lab bo'lmadi");
    } catch (e) {
      if (!mounted) return;
      setState(() => _cidMsg = "Bazani bog'lab bo'lmadi: $e");
    }
    await _refreshCallerId();
  }

  Widget _cidStatusRow(bool ok, String text) {
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

  Future<void> _refreshBio() async {
    final avail = await BiometricService.instance.isAvailable();
    final on = await AuthService.instance.isBiometricEnabled();
    final label = avail ? await BiometricService.instance.label() : '';
    if (!mounted) return;
    setState(() {
      _bioAvailable = avail;
      _bioOn = on;
      if (label.isNotEmpty) _bioLabel = label;
    });
  }

  Future<void> _toggleBio(bool on) async {
    if (!on) {
      await AuthService.instance.setBiometricEnabled(false);
      if (!mounted) return;
      setState(() => _bioOn = false);
      return;
    }

    // Yoqishdan oldin haqiqatan ishlashini tekshiramiz
    final res = await BiometricService.instance
        .authenticate("$_bioLabel ni yoqish uchun tasdiqlang");
    if (!mounted) return;

    if (res.ok) {
      await AuthService.instance.setBiometricEnabled(true);
      if (!mounted) return;
      setState(() => _bioOn = true);
    } else if (res.message != null) {
      setState(() {
        _pmsg = res.message!;
        _pmsgError = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _oldP.dispose();
    _newP.dispose();
    _confP.dispose();
    super.dispose();
  }

  Future<void> _refreshDbStatus() async {
    final hasKey = await DbService.instance.hasStoredKey();
    if (!mounted) return;

    final open = DbService.instance.isOpen;
    final path = DbService.instance.path;

    setState(() {
      _hasKey = hasKey;
      if (open && path != null) {
        _dbMsg = 'Ulangan: $path';
        _dbMsgError = false;
      } else if (path != null) {
        _dbMsg = 'Topildi, lekin ochilmagan: $path';
        _dbMsgError = true;
      } else {
        _dbMsg = 'Baza ulanmagan';
        _dbMsgError = true;
      }
    });
  }

  Future<void> _changePassword() async {
    final old = _oldP.text.trim();
    final nw = _newP.text.trim();
    final conf = _confP.text.trim();

    final stored = await AuthService.instance.loadHash();
    if (!mounted) return;

    if (stored != null &&
        AuthService.instance.hashPass(old) != stored) {
      _setPmsg("Eski parol noto'g'ri", error: true);
      return;
    }
    if (nw.length < 4) {
      _setPmsg('Yangi parol kamida 4 belgi', error: true);
      return;
    }
    if (nw != conf) {
      _setPmsg('Yangi parollar mos kelmadi', error: true);
      return;
    }

    try {
      await AuthService.instance.saveHash(AuthService.instance.hashPass(nw));
    } catch (e) {
      if (!mounted) return;
      _setPmsg('Saqlashda xato: $e', error: true);
      return;
    }
    if (!mounted) return;

    _oldP.clear();
    _newP.clear();
    _confP.clear();
    _setPmsg("Parol muvaffaqiyatli o'zgartirildi", error: false);
  }

  void _setPmsg(String text, {required bool error}) {
    setState(() {
      _pmsg = text;
      _pmsgError = error;
    });
  }

  Future<void> _importDb() async {
    // 1) Faylni tanlash
    final src = await DbService.instance.pickDatabaseFile();
    if (!mounted) return;
    if (src == null) {
      setState(() {
        _dbMsg = 'Fayl tanlanmadi (.db / .sqlite bo\'lishi kerak)';
        _dbMsgError = true;
      });
      return;
    }

    // 2) Parolini so'rash
    final pass = await askDbPassword(
      context,
      title: 'Bazani import qilish',
      message: 'Agar baza AES bilan shifrlangan bo\'lsa, parolini kiriting. '
          'Shifrlanmagan bo\'lsa — bo\'sh qoldiring.',
      allowEmpty: true,
    );
    if (pass == null || !mounted) return;

    // 3) Tekshirib o'rnatish
    setState(() {
      _importing = true;
      _dbMsg = 'Tekshirilmoqda...';
      _dbMsgError = false;
    });

    final res = await DbService.instance.installDatabase(src, pass);
    if (!mounted) return;

    setState(() {
      _importing = false;
      if (res.isOk) {
        _dbMsg = 'Baza muvaffaqiyatli yuklandi';
        _dbMsgError = false;
      } else {
        _dbMsg = res.message ?? 'Import xatosi';
        _dbMsgError = true;
      }
    });

    await _refreshDbStatus();
  }

  /// Saqlangan baza parolini o'chirish
  Future<void> _forgetKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          "Parolni o'chirish",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'Saqlangan baza paroli o\'chiriladi va baza yopiladi. '
          'Keyingi qidiruvda parol qaytadan so\'raladi.',
          style: TextStyle(color: AppColors.labelBlue, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor',
                style: TextStyle(color: AppColors.labelBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("O'chirish",
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await DbService.instance.forgetKey();
    if (!mounted) return;

    setState(() {
      _dbMsg = "Parol o'chirildi";
      _dbMsgError = false;
    });
    await _refreshDbStatus();
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
                Row(
                  children: [
                    CircleBtn(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sozlamalar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      // ── Baza ──────────────────────────────
                      Panel(
                        spacing: 10,
                        children: [
                          const Text(
                            "Ma'lumotlar bazasi",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Platform.isIOS
                                ? "iOS'da baza faqat import orqali yuklanadi."
                                : "royxat.db ni /sdcard/qidiruv/ ga qo'ying "
                                    "yoki bu yerdan import qiling.",
                            style: const TextStyle(
                              color: AppColors.labelBlue,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                _hasKey ? Icons.lock : Icons.lock_open,
                                size: 16,
                                color: _hasKey
                                    ? AppColors.success
                                    : AppColors.hint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _hasKey
                                    ? 'Shifrlangan — parol saqlangan'
                                    : 'Parol saqlanmagan',
                                style: TextStyle(
                                  color: _hasKey
                                      ? AppColors.success
                                      : AppColors.hint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (_dbMsg.isNotEmpty)
                            Text(
                              _dbMsg,
                              style: TextStyle(
                                color: _dbMsgError
                                    ? AppColors.error
                                    : AppColors.success,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          PrimaryBtn(
                            text: _importing
                                ? 'Yuklanmoqda...'
                                : 'Bazani import qilish',
                            height: 50,
                            onTap: _importing ? null : _importDb,
                          ),
                          if (_hasKey)
                            SizedBox(
                              width: double.infinity,
                              child: GhostBtn(
                                text: "Saqlangan parolni o'chirish",
                                onTap: _forgetKey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Biometrika ────────────────────────
                      if (_bioAvailable) ...[
                        Panel(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$_bioLabel bilan kirish',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Rang berilmagan — Material 3 switch'i
                                // colorScheme.primary (accent) ni oladi,
                                // activeColor esa yangi Flutter'da eskirgan.
                                Switch(
                                  value: _bioOn,
                                  onChanged: _toggleBio,
                                ),
                              ],
                            ),
                            Text(
                              _bioOn
                                  ? "Ilova ochilganda $_bioLabel so'raladi. "
                                      "Parol zaxira yo'l sifatida qoladi."
                                  : "Yoqilsa, ilovaga parol yozmasdan "
                                      "$_bioLabel bilan kirasiz.",
                              style: const TextStyle(
                                color: AppColors.labelBlue,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Qo'ng'iroqda ko'rsatish ───────────
                      if (Platform.isAndroid && _cidSupported) ...[
                        Panel(
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
                              "Kiruvchi qo'ng'iroqda ekran ustida kichik "
                              "oyna chiqadi. Ishlashi uchun ikkala ruxsat "
                              "ham kerak.",
                              style: TextStyle(
                                color: AppColors.labelBlue,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            _cidStatusRow(
                              _cidRole,
                              _cidRole
                                  ? "Qo'ng'iroqlarni tekshirish roli berilgan"
                                  : "Qo'ng'iroqlarni tekshirish roli yo'q",
                            ),
                            _cidStatusRow(
                              _cidOverlay,
                              _cidOverlay
                                  ? 'Ekran ustida ko\'rsatish ruxsati bor'
                                  : "Ekran ustida ko'rsatish ruxsati yo'q",
                            ),
                            _cidStatusRow(
                              _cidDb,
                              _cidDb
                                  ? "Baza bog'langan"
                                  : "Baza bog'lanmagan — ism ko'rsatilmaydi",
                            ),
                            if (_cidMsg.isNotEmpty)
                              Text(
                                _cidMsg,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            if (!_cidRole)
                              PrimaryBtn(
                                text: 'Rolni berish',
                                height: 50,
                                onTap: () => _cidRequest('requestRole'),
                              ),
                            if (!_cidOverlay)
                              SizedBox(
                                width: double.infinity,
                                child: GhostBtn(
                                  text: 'Oyna ruxsatini berish',
                                  onTap: () => _cidRequest('requestOverlay'),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: GhostBtn(
                                text: _cidDb
                                    ? "Bazani qayta bog'lash"
                                    : "Bazani bog'lash",
                                onTap: _cidSyncDb,
                              ),
                            ),
                            if (_cidRole && _cidOverlay && _cidDb)
                              const Text(
                                "Tayyor. Bazani almashtirsangiz yoki "
                                "parolini o'zgartirsangiz, shu yerdan "
                                "qayta bog'lang.",
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Parol ─────────────────────────────
                      Panel(
                        children: [
                          const Text(
                            "Parolni o'zgartirish",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          DarkInput(
                            controller: _oldP,
                            hint: 'Eski parol',
                            obscure: true,
                          ),
                          DarkInput(
                            controller: _newP,
                            hint: 'Yangi parol',
                            obscure: true,
                          ),
                          DarkInput(
                            controller: _confP,
                            hint: 'Yangi parolni tasdiqlang',
                            obscure: true,
                            action: TextInputAction.done,
                            onSubmitted: (_) => _changePassword(),
                          ),
                          if (_pmsg.isNotEmpty)
                            Text(
                              _pmsg,
                              style: TextStyle(
                                color: _pmsgError
                                    ? AppColors.error
                                    : AppColors.success,
                                fontSize: 13,
                              ),
                            ),
                          PrimaryBtn(
                            text: 'Saqlash',
                            height: 50,
                            onTap: _changePassword,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Dastur haqida ─────────────────────
                      const Panel(
                        spacing: 8,
                        children: [
                          Text(
                            'Dastur haqida',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Muallif: O.Saparov',
                            style: TextStyle(
                              color: AppColors.labelBlue,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Tel: 921929884',
                            style: TextStyle(
                              color: AppColors.labelBlue,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
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
