import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric tekshiruv natijasi.
/// `ok` — tasdiqlandi; `message` bo'sh bo'lsa foydalanuvchi o'zi bekor qilgan.
class BioResult {
  final bool ok;
  final String? message;
  const BioResult(this.ok, [this.message]);
}

/// Face ID / Touch ID / barmoq izi orqali ilovaga kirish.
///
/// DIQQAT: bu xizmat faqat ILOVA qulfini ochadi — baza shifrlash kalitiga
/// aloqasi yo'q. Baza kaliti Keychain/Keystore'da saqlanadi va
/// `DbService.open()` uni o'zi oladi.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final _auth = LocalAuthentication();

  /// Qurilmada biometrika bor va ro'yxatdan o'tganmi?
  ///
  /// `canCheckBiometrics` — sensor bor-yo'qligi;
  /// `isDeviceSupported()` — OS darajasida qo'llab-quvvatlash;
  /// `getAvailableBiometrics()` — aynan ro'yxatga olingan barmoq/yuz bormi.
  /// Uchalasi ham kerak: sensor bor, lekin hech narsa ro'yxatga olinmagan
  /// qurilmada `authenticate` xato beradi.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      debugPrint('Biometrika: canCheck=$canCheck supported=$supported '
          'enrolled=$enrolled');
      return canCheck && supported && enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('Biometrikani tekshirishda xato: $e');
      return false;
    }
  }

  /// Tugmada ko'rsatiladigan nom: "Face ID", "Touch ID" yoki "Barmoq izi".
  Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      final hasFace = types.contains(BiometricType.face);
      if (Platform.isIOS) return hasFace ? 'Face ID' : 'Touch ID';
      return hasFace ? 'Yuz orqali' : 'Barmoq izi';
    } catch (_) {
      return 'Biometrika';
    }
  }

  /// Biometrik tekshiruvni ishga tushiradi.
  ///
  /// `biometricOnly: true` — qurilma PIN kodi taklif qilinmaydi, chunki
  /// ilovaning o'z paroli allaqachon zaxira yo'l sifatida turadi.
  /// Boshqa parametrlar (`stickyAuth` va h.k.) ataylab berilmagan:
  /// local_auth versiyalari orasida ularning nomi o'zgargan.
  Future<BioResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true),
      );
      debugPrint('Biometrika natijasi: $ok');
      // ok == false — foydalanuvchi bekor qildi, bu xato emas
      return BioResult(ok);
    } on PlatformException catch (e) {
      debugPrint('Biometrika xatosi: ${e.code} — ${e.message}');
      return BioResult(false, _explain(e));
    } catch (e) {
      debugPrint('Biometrika xatosi: $e');
      return BioResult(false, 'Biometrika ishlamadi');
    }
  }

  /// Platforma xato kodlarini o'zbekcha matnga aylantiradi.
  String _explain(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometrika mavjud emas';
      case 'NotEnrolled':
        return Platform.isIOS
            ? "Sozlamalarda Face ID / Touch ID qo'shilmagan"
            : "Sozlamalarda barmoq izi qo'shilmagan";
      case 'LockedOut':
        return "Ko'p marta xato — parol bilan kiring";
      case 'PermanentlyLockedOut':
        return 'Biometrika bloklandi — parol bilan kiring';
      case 'no_fragment_activity':
        // Android: MainActivity FlutterFragmentActivity'dan meros olmagan
        return 'Ilova sozlamasida xato (fragment activity)';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Biometrika xatosi: ${e.code}';
    }
  }
}
