import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/lock_screen.dart';
import 'services/quick_search_link.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Barcha yo'nalishlar — telefon yon tomonga burilsa ham ishlaydi.
  // Avval faqat portret ruxsat etilgan edi, shuning uchun ekran
  // burilmay turardi.
  //
  // DIQQAT: iOS'da bu ro'yxat Info.plist dagi
  // UISupportedInterfaceOrientations dan kengroq bo'la olmaydi —
  // u yerda ham landshaft ochilishi kerak (tool/patch_ios.sh).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Action Button / Shortcuts: getcontact://search?q=... havolalari.
  // So'rov qidiruv ekrani ochilganda (qulf ochilgandan keyin) bajariladi.
  QuickSearchLink.instance.init();

  runApp(const GetcontactApp());
}

class GetcontactApp extends StatelessWidget {
  const GetcontactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Getcontact',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LockScreen(),
    );
  }
}
