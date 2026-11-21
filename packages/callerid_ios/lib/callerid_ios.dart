import 'package:flutter/services.dart';

/// iOS Call Directory extension bilan aloqa.
class CallerIdIos {
  CallerIdIos._();

  static const _ch = MethodChannel('getcontact/callerid_ios');

  /// Asosiy ilova va extension uchun umumiy papka.
  /// `null` — App Group ishlamayapti (ilova uni qo'llamaydigan usulda
  /// imzolangan).
  static Future<String?> containerPath() =>
      _ch.invokeMethod<String>('containerPath');

  /// Bo'laklar (extension'lar) soni.
  /// DIQQAT: Swift plaginidagi `parts` va add_call_directory.rb dagi PARTS
  /// bilan bir xil bo'lishi shart.
  static const parts = 4;

  /// {container: bool, parts: int, enabledCount: int,
  ///  states: ['enabled'|'disabled'|'unknown', ...], error?: String}
  static Future<Map<String, dynamic>> status() async =>
      (await _ch.invokeMapMethod<String, dynamic>('status')) ?? const {};

  /// [part]-bo'lak extension'ini qayta yuklaydi (1…[parts]).
  static Future<ReloadResult> reload(int part) async {
    final m =
        await _ch.invokeMapMethod<String, dynamic>('reload', part) ?? const {};
    return ReloadResult(
      ok: m['ok'] == true,
      disabled: m['disabled'] == true,
      message: m['message'] as String?,
    );
  }

  /// Ekranning avtomatik o'chishini vaqtincha to'xtatadi.
  static Future<void> keepAwake(bool on) =>
      _ch.invokeMethod<void>('keepAwake', on);

  /// Sozlamalarning «Блокировка и идентификация вызовов» bo'limini ochadi.
  static Future<bool> openSettings() async =>
      (await _ch.invokeMethod<bool>('openSettings')) ?? false;
}

/// Extension'ni qayta yuklash natijasi.
class ReloadResult {
  final bool ok;

  /// Extension Sozlamalarda o'chirilgan — xato emas, faqat ogohlantirish
  final bool disabled;

  final String? message;

  const ReloadResult({required this.ok, this.disabled = false, this.message});
}
