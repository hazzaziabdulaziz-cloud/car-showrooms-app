import 'package:material_ui/material_ui.dart';

class LuxuryColors {
  static const Color navy = Color(0xFF0B192C);
  static const Color navyLight = Color(0xFF162A45);
  static const Color gold = Color(0xFFC5A059);
  static const Color goldSoft = Color(0xFFF6F0E4);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E7EC);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color success = Color(0xFF067647);
  static const Color successBg = Color(0xFFECFDF3);
  static const Color danger = Color(0xFFB42318);
}

InputDecoration luxuryInput(String label, {IconData? icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 19, color: LuxuryColors.navyLight) : null,
    filled: true,
    fillColor: LuxuryColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: LuxuryColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: LuxuryColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: LuxuryColors.gold, width: 1.6),
    ),
  );
}
