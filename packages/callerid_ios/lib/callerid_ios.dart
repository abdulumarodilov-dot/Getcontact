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

  /// {container: bool, enabled: 'enabled'|'disabled'|'unknown', error?: String}
  static Future<Map<String, dynamic>> status() async =>
      (await _ch.invokeMapMethod<String, dynamic>('status')) ?? const {};

  /// Extension'ni qayta yuklaydi. `null` — muvaffaqiyat, aks holda xato matni.
  static Future<String?> reload() => _ch.invokeMethod<String>('reload');

  /// Ekranning avtomatik o'chishini vaqtincha to'xtatadi.
  static Future<void> keepAwake(bool on) =>
      _ch.invokeMethod<void>('keepAwake', on);

  /// Sozlamalarning «Блокировка и идентификация вызовов» bo'limini ochadi.
  static Future<bool> openSettings() async =>
      (await _ch.invokeMethod<bool>('openSettings')) ?? false;
}
