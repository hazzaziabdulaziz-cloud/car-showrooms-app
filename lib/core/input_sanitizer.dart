class InputSanitizer {
  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  static String normalizeDigits(String input) {
    var out = input;
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(_arabicDigits[i], '$i');
      out = out.replaceAll(_persianDigits[i], '$i');
    }
    return out;
  }

  static String cleanSaudiPhone(String input) {
    var digits = normalizeDigits(input).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00966')) {
      digits = '0${digits.substring(5)}';
    } else if (digits.startsWith('966') && digits.length >= 12) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('5') && digits.length == 9) {
      digits = '0$digits';
    }
    return digits;
  }

  static bool isValidSaudiPhone(String input) {
    final cleaned = cleanSaudiPhone(input);
    return RegExp(r'^05[0-9]{8}$').hasMatch(cleaned);
  }
}
