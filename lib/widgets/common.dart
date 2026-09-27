import 'package:flutter/material.dart';
import '../theme.dart';

/// Yumaloq kvadrat ichidagi ikonka (Kivy'dagi IconBox)
class IconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final double radius;
  final Color? color;

  const IconBox({
    super.key,
    required this.icon,
    this.size = 40,
    this.radius = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.iconBoxBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.iconBoxBorder, width: 1.2),
      ),
      child: Icon(icon, size: size * 0.52, color: color ?? AppColors.accent),
    );
  }
}

/// Dumaloq tugma (Kivy'dagi CircleBtn)
class CircleBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool filled;

  const CircleBtn({
    super.key,
    required this.icon,
    this.size = 44,
    this.onTap,
    this.iconColor,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.iconBoxBg : Colors.transparent,
      shape: CircleBorder(
        side: filled
            ? const BorderSide(color: AppColors.iconBoxBorder, width: 1.2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              size: size * 0.48, color: iconColor ?? AppColors.accent),
        ),
      ),
    );
  }
}

/// Qorong'i kiritish maydoni (Kivy'dagi DarkInput)
class DarkInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final void Function(String)? onSubmitted;
  final TextInputAction? action;

  const DarkInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onSubmitted,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      textInputAction: action,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.hint, fontSize: 16),
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.inputBorderFocus, width: 1.8),
        ),
      ),
    );
  }
}

/// Asosiy ko'k tugma (Kivy'dagi PrimaryBtn)
class PrimaryBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double height;

  const PrimaryBtn({
    super.key,
    required this.text,
    this.onTap,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1F63D6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Konturli tugma (Kivy'dagi GhostBtn)
class GhostBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double height;

  const GhostBtn({
    super.key,
    required this.text,
    this.onTap,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Gayka ikonali "Sozlamalar" tugmasi (Kivy'dagi GoldPill)
class SettingsPill extends StatelessWidget {
  final VoidCallback? onTap;
  const SettingsPill({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.pillBorder, width: 1.5),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings, size: 17, color: AppColors.pillText),
              SizedBox(width: 6),
              Text(
                'Sozlamalar',
                style: TextStyle(
                  color: AppColors.pillText,
                  fontSize: 13,
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

/// Sozlamalar ekranidagi panel (Kivy'dagi Panel)
class Panel extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const Panel({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) items.add(SizedBox(height: spacing));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }
}
