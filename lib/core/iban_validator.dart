class IbanValidator {
  static String? validateSaudiIban(String? value) {
    final clean = (value ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return 'يرجى إدخال رقم الحساب البنكي الرسمي (IBAN).';
    if (!clean.startsWith('SA') || clean.length != 24) {
      return 'رقم الآيبان السعودي يجب أن يبدأ بـ SA ويتكون من 24 خانة.';
    }
    return null;
  }
}
