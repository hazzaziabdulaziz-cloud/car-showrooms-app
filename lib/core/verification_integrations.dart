class VerificationResult {
  final bool valid;
  final String message;
  final Map<String, dynamic> metadata;

  const VerificationResult({
    required this.valid,
    required this.message,
    this.metadata = const {},
  });
}

class VerificationIntegrations {
  /// فحص صيغة الرقم الموحد للمنشأة (700) قبل إرساله لـ Wathq API عبر Cloud Functions
  static VerificationResult validateCrNumberFormat(String crNumber) {
    final cleaned = crNumber.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^700\d{7}$').hasMatch(cleaned) || RegExp(r'^\d{10}$').hasMatch(cleaned)) {
      return VerificationResult(
        valid: true,
        message: 'صيغة السجل/الرقم الموحد صحيحة وجاهزة للتحقق الآلي عبر واثق.',
        metadata: {'cr_number': cleaned},
      );
    }
    return const VerificationResult(
      valid: false,
      message: 'يجب إدخال رقم موحد يبدأ بـ 700 (10 أرقام) أو سجل تجاري صحيح.',
    );
  }

  /// فحص رابط QR لشهادة العمل الحر الرسمية (freelance.sa)
  static VerificationResult validateFreelanceQrUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) {
      return const VerificationResult(valid: false, message: 'رابط رمز QR غير صالح.');
    }
    final host = uri.host.toLowerCase();
    if (host.endsWith('freelance.sa')) {
      return VerificationResult(
        valid: true,
        message: 'رابط رسمي معتمد من بوابة العمل الحر.',
        metadata: {'verified_host': host, 'url': uri.toString()},
      );
    }
    return const VerificationResult(
      valid: false,
      message: 'الرابط لا يتبع النطاق الرسمي لبوابة العمل الحر (freelance.sa).',
    );
  }

  /// فحص مبدئي لرقم الهوية الوطنية / الإقامة قبل استدعاء نفاذ (Nafath)
  static VerificationResult validateNationalIdFormat(String id) {
    final cleaned = id.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^[12]\d{9}$').hasMatch(cleaned)) {
      return VerificationResult(
        valid: true,
        message: 'صيغة الهوية صحيحة وجاهزة لإرسال طلب التوثيق عبر نفاذ.',
        metadata: {'national_id': cleaned},
      );
    }
    return const VerificationResult(
      valid: false,
      message: 'رقم الهوية/الإقامة يجب أن يتكون من 10 أرقام ويبدأ بـ 1 أو 2.',
    );
  }
}
