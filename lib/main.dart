import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

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
