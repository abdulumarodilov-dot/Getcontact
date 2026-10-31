import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS'dan kelgan `getcontact://...` havolalari.
class QuickLinkIos {
  QuickLinkIos._();

  static const _ch = MethodChannel('getcontact/links');

  /// Tinglashni boshlaydi. [onLink] har bir havola uchun chaqiriladi —
  /// shu jumladan ilova havola bilan ochilgan bo'lsa, o'sha havola uchun ham.
  static Future<void> listen(void Function(Uri uri) onLink) async {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        final u = Uri.tryParse(call.arguments as String);
        if (u != null) onLink(u);
      }
    });
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    // Plagin engine bilan birga ro'yxatdan o'tadi — juda erta chaqirilsa
    // hali tayyor bo'lmasligi mumkin, shuning uchun bir necha marta urinamiz.
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final pending =
            await _ch.invokeListMethod<String>('ready') ?? const <String>[];
        for (final s in pending) {
          final u = Uri.tryParse(s);
          if (u != null) onLink(u);
        }
        return;
      } on MissingPluginException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } catch (e) {
        debugPrint('quick_link_ios: $e');
        return;
      }
    }
  }
}
