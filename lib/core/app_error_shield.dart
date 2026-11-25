import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

/// درع حماية شامل للتطبيق: يمنع توقف البرنامج بالكامل ويعزل الأخطاء.
class AppErrorShield {
  static bool _initialized = false;

  /// استدعِ هذه الدالة مرة واحدة داخل main() قبل runApp
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // 1. استبدال شاشة الخطأ الحمراء بواجهة عربية آمنة ومعزولة
    ErrorWidget.builder = (FlutterErrorDetails details) {
      logError(details.exception, details.stack, source: 'WidgetBuild');
      return const _IsolatedErrorCard(
        message: 'تعذّر عرض هذا الجزء مؤقتاً، باقي التطبيق يعمل بشكل طبيعي.',
      );
    };

    // 2. التقاط أخطاء Flutter غير المتوقعة
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logError(details.exception, details.stack, source: 'FlutterError');
    };

    // 3. التقاط أخطاء Async / Platform غير المتوقعة
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logError(error, stack, source: 'PlatformError');
      return true; // منع إغلاق التطبيق
    };
  }

  /// تسجيل الخطأ بصمت في Firestore ليراجعه الأدمن لاحقاً
  static Future<void> logError(
    Object error,
    StackTrace? stack, {
    String source = 'App',
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final errStr = error.toString();
      final stackStr = stack?.toString() ?? '';
      await FirebaseFirestore.instance.collection('app_error_logs').add({
        'uid': uid,
        'source': source,
        'error': errStr.length > 500 ? errStr.substring(0, 500) : errStr,
        'stack': stackStr.length > 800 ? stackStr.substring(0, 800) : stackStr,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // لا تسمح لفشل التسجيل بتعطيل التطبيق
    }
  }

  /// تشغيل أي عملية حساسة بأمان مع رسالة خطأ واضحة للمستخدم
  static Future<T?> runSafe<T>(
    BuildContext context,
    Future<T> Function() action, {
    String fallbackMessage = 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.',
  }) async {
    try {
      return await action();
    } on FirebaseException catch (e, st) {
      logError(e, st, source: 'Firebase:${e.code}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyFirebaseError(e.code))),
        );
      }
      return null;
    } catch (e, st) {
      logError(e, st, source: 'SafeAction');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fallbackMessage)),
        );
      }
      return null;
    }
  }

  static String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
      case 'unavailable':
      case 'network-request-failed':
        return 'تعذّر الاتصال بالإنترنت، تحقق من الشبكة وحاول مجدداً.';
      case 'not-found':
        return 'العنصر المطلوب غير موجود أو تم حذفه.';
      default:
        return 'تعذّر إتمام العملية حالياً ($code).';
    }
  }
}

/// عازل أخطاء لأي قسم أو بطاقة: إذا خرب هذا القسم لا يتأثر باقي التطبيق
class FaultBoundary extends StatelessWidget {
  final Widget Function() builder;
  final String fallbackText;

  const FaultBoundary({
    super.key,
    required this.builder,
    this.fallbackText = 'تعذّر تحميل هذا القسم مؤقتاً.',
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder();
    } catch (e, st) {
      AppErrorShield.logError(e, st, source: 'FaultBoundary');
      return _IsolatedErrorCard(message: fallbackText);
    }
  }
}

class _IsolatedErrorCard extends StatelessWidget {
  final String message;
  const _IsolatedErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
