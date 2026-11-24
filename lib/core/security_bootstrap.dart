import 'package:flutter/foundation.dart';

class SecurityBootstrap {
  static const String saudiRegion = 'me-central2'; // الرياض / الدمام للامتثال لـ PDPL
  static bool get isDemoModeAllowed => kDebugMode;

  /// يتم استدعاؤها في main() بعد تفعيل حزمة firebase_app_check قبل الإطلاق
  static Future<void> initializeSecurityGuard() async {
    debugPrint('[SecurityBootstrap] Region: $saudiRegion | DebugDemo: $isDemoModeAllowed');
  }
}
