import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppColors {
  static const Color background = Color(0xFFF7F7F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F1EE);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);
  static const Color primary = Color(0xFF14284B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF15803D);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFF92400E);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFF991B1B);
}

class Formatters {
  static String sar(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final revIdx = s.length - i;
      buf.write(s[i]);
      if (revIdx > 1 && revIdx % 3 == 1) buf.write(',');
    }
    return '${buf.toString()} ر.س';
  }
}

class SecurityGuard {
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>|&[^;]+;');
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  static String sanitizeText(String input, {int maxLength = 120}) {
    final cleaned = input.replaceAll(_htmlTagRegex, '').replaceAll(_controlChars, '').trim();
    if (cleaned.length <= maxLength) return cleaned;
    return cleaned.substring(0, maxLength).trim();
  }

  static String? validateRequiredText(String? value, String fieldLabel, {int min = 2, int max = 100}) {
    final clean = sanitizeText(value ?? '', maxLength: max);
    if (clean.isEmpty) return 'يرجى إدخال $fieldLabel.';
    if (clean.length < min) return 'يجب ألا يقل $fieldLabel عن $min أحرف.';
    return null;
  }

  static String? validatePositiveInt(String? value, String fieldLabel, {int min = 1, int max = 5000000}) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'يرجى إدخال رقم صحيح في $fieldLabel.';
    if (parsed < min || parsed > max) return 'قيمة $fieldLabel يجب أن تكون بين $min و $max.';
    return null;
  }

  static String? validateYear(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    final currentYear = DateTime.now().year + 1;
    if (parsed == null || parsed < 1990 || parsed > currentYear) {
      return 'يرجى إدخال سنة صنع صحيحة (1990 - $currentYear).';
    }
    return null;
  }

  static String? validateCrNumber(String? value) {
    final digitsOnly = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) return 'رقم السجل أو الرقم الموحد يجب أن يكون 10 أرقام.';
    return null;
  }
}

class SafeErrorMapper {
  static String toUserMessage(Object error) {
    if (error is TimeoutException) {
      return 'انتهت مهلة الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'لا تملك الصلاحية لتنفيذ هذا الإجراء حالياً.';
        case 'unavailable':
          return 'الخدمة غير متاحة مؤقتاً. يرجى المحاولة بعد قليل.';
        case 'network-request-failed':
          return 'حدث انقطاع في الشبكة أثناء الاتصال بقاعدة البيانات.';
        default:
          return 'تعذر إتمام العملية على قاعدة البيانات.';
      }
    }
    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
  }
}
