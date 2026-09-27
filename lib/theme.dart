import 'package:flutter/material.dart';

/// Kivy ilovasidagi ranglar aynan ko'chirildi
class AppColors {
  // Fon gradienti
  static const bgTop = Color(0xFF05193F);      // 0.02, 0.10, 0.25
  static const bgBottom = Color(0xFF020A1F);   // 0.008, 0.04, 0.12

  // Kartochka
  static const cardBg = Color(0xFF081F47);     // 0.03, 0.12, 0.28
  static const cardBorder = Color(0xFF1A478C); // 0.10, 0.28, 0.55

  // Qidiruv maydoni
  static const inputBg = Color(0xFF081C42);        // 0.03, 0.11, 0.26
  static const inputBorder = Color(0xFF1F57B8);    // 0.12, 0.34, 0.72
  static const inputBorderFocus = Color(0xFF2E80FA); // 0.18, 0.50, 0.98
  static const hint = Color(0xFF5C80BD);           // 0.36, 0.50, 0.74

  // Matnlar
  static const accent = Color(0xFF66A8FF);      // 0.40, 0.66, 1
  static const labelBlue = Color(0xFF8CB8F2);   // 0.55, 0.72, 0.95
  static const subtitle = Color(0xFF80A8E6);    // 0.50, 0.66, 0.90

  // Sozlamalar tugmasi (gayka)
  static const pillBorder = Color(0xFF737F94);  // 0.45, 0.50, 0.58
  static const pillText = Color(0xFFCCD6E6);    // 0.80, 0.84, 0.90

  // Holat
  static const error = Color(0xFFFF7070);
  static const success = Color(0xFF59D98C);     // 0.35, 0.85, 0.55

  // Ikonka fon quticha
  static const iconBoxBg = Color(0xFF0D2B5C);
  static const iconBoxBorder = Color(0xFF1E4A8F);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgBottom,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.cardBg,
      error: AppColors.error,
    ),
    // Const ranglar — Flutter versiyasiga bog'liq emas
    splashColor: const Color(0x1F66A8FF),
    highlightColor: const Color(0x1466A8FF),
  );
}

/// Ekran foni — vertikal gradient (Kivy'dagi make_gradient bilan bir xil)
class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgBottom],
        ),
      ),
      child: child,
    );
  }
}
