import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kivy'dagi hash_pass / load_pass_hash / save_pass_hash ko'chirmasi.
/// Fayl o'rniga SharedPreferences ishlatiladi (iOS'da ham ishlaydi).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _key = 'qidiruv_parol_hash';

  String hashPass(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  Future<String?> loadHash() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_key);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  Future<void> saveHash(String hash) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, hash);
  }

  /// Parol hali o'rnatilmaganmi? (birinchi ishga tushirish)
  Future<bool> isSetupMode() async => (await loadHash()) == null;

  Future<bool> verify(String password) async {
    final stored = await loadHash();
    if (stored == null) return false;
    return hashPass(password) == stored;
  }
}
