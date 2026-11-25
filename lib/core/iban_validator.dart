class IbanValidator {
  static String? validateSaudiIban(String? value) {
    final clean = (value ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return 'يرجى إدخال رقم الحساب البنكي الرسمي (IBAN).';
    if (!RegExp(r'^SA\d{22}$').hasMatch(clean)) {
      return 'رقم الآيبان السعودي يجب أن يبدأ بـ SA ويتبعه 22 رقماً.';
    }
    final rearranged = '${clean.substring(4)}2810${clean.substring(2, 4)}';
    final mod97 = BigInt.parse(rearranged) % BigInt.from(97);
    if (mod97 != BigInt.one) {
      return 'رقم الآيبان غير صحيح حسابياً — يرجى مراجعة الأرقام المدخلة.';
    }
    return null;
  }
}
