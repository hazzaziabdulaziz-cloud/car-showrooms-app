import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef JsonMap = Map<String, dynamic>;

/// محرك الإحصائيات الشاملة + الخصومات + الفواتير + سيستم الحسابات (الداخل والطالع)
class AnalyticsAndAccountingService {
  static final _db = FirebaseFirestore.instance;
  static const double vatRate = 0.15; // ضريبة القيمة المضافة 15%

  // ==================== 1. نظام الإحصائيات والتتبع ====================

  static Future<void> trackEvent(
    String eventType, {
    JsonMap? meta,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final now = DateTime.now();
      final dayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final batch = _db.batch();

      final globalRef = _db.collection('analytics_summary').doc('global');
      batch.set(
        globalRef,
        {
          eventType: FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final dailyRef = _db.collection('analytics_daily').doc(dayKey);
      batch.set(
        dailyRef,
        {
          'date': dayKey,
          eventType: FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final eventRef = _db.collection('analytics_events').doc();
      batch.set(eventRef, {
        'type': eventType,
        'uid': uid,
        'meta': meta ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (_) {
      // التتبع لا يوقف تجربة المستخدم أبداً
    }
  }

  static const String evAppOpen = 'app_opens';
  static const String evBrowseShowroom = 'browse_showrooms';
  static const String evBrowseCar = 'browse_cars';
  static const String evBookCar = 'book_car';
  static const String evBookFlatbed = 'book_flatbed';
  static const String evBookInspection = 'book_inspection';

  // ==================== 2. صلاحيات الخصم والكوبونات ====================

  static Future<void> createDiscountCode({
    required String code,
    required String type, // 'percent' أو 'fixed'
    required double value,
    required String scope, // 'all' | 'car' | 'inspection' | 'flatbed' | 'subscription'
    int maxUses = 100,
    DateTime? expiresAt,
  }) async {
    final normalized = code.trim().toUpperCase();
    await _db.collection('discount_codes').doc(normalized).set({
      'code': normalized,
      'type': type,
      'value': value,
      'scope': scope,
      'maxUses': maxUses,
      'usedCount': 0,
      'active': true,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<JsonMap> validateDiscount({
    required String code,
    required double subtotal,
    required String scope,
  }) async {
    final normalized = code.trim().toUpperCase();
    final doc = await _db.collection('discount_codes').doc(normalized).get();
    if (!doc.exists) {
      return {'valid': false, 'message': 'كود الخصم غير موجود.'};
    }
    final data = doc.data()!;
    if (data['active'] != true) {
      return {'valid': false, 'message': 'كود الخصم غير مفعّل حالياً.'};
    }
    final int used = (data['usedCount'] ?? 0) as int;
    final int maxUses = (data['maxUses'] ?? 0) as int;
    if (maxUses > 0 && used >= maxUses) {
      return {'valid': false, 'message': 'تم استهلاك الحد الأقصى لهذا الكود.'};
    }
    final Timestamp? exp = data['expiresAt'] as Timestamp?;
    if (exp != null && exp.toDate().isBefore(DateTime.now())) {
      return {'valid': false, 'message': 'انتهت صلاحية كود الخصم.'};
    }
    final String codeScope = (data['scope'] ?? 'all') as String;
    if (codeScope != 'all' && codeScope != scope) {
      return {'valid': false, 'message': 'هذا الكود غير مخصص لهذه الخدمة.'};
    }

    final double val = (data['value'] as num).toDouble();
    final double discountAmount = data['type'] == 'percent'
        ? (subtotal * (val / 100.0))
        : val;
    final double clamped =
        discountAmount > subtotal ? subtotal : discountAmount;

    return {
      'valid': true,
      'code': normalized,
      'discountAmount': double.parse(clamped.toStringAsFixed(2)),
      'message': 'تم تطبيق الخصم بنجاح.',
    };
  }

  // ==================== 3. الفواتير وسيستم الحسابات ====================

  static Future<String> issueInvoiceAndRecordLedger({
    required String orderId,
    required String customerName,
    required String customerUid,
    required String serviceType, // 'car_booking' | 'inspection' | 'flatbed' | 'subscription'
    required double subtotal,
    double discountAmount = 0.0,
    String? discountCode,
    String notes = '',
  }) async {
    final afterDiscount = (subtotal - discountAmount).clamp(0.0, double.infinity);
    final vatAmount = double.parse((afterDiscount * vatRate).toStringAsFixed(2));
    final total = double.parse((afterDiscount + vatAmount).toStringAsFixed(2));
    final invoiceNumber =
        'INV-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final batch = _db.batch();

    final invRef = _db.collection('invoices').doc(invoiceNumber);
    batch.set(invRef, {
      'invoiceNumber': invoiceNumber,
      'orderId': orderId,
      'customerUid': customerUid,
      'customerName': customerName,
      'serviceType': serviceType,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'discountCode': discountCode,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'total': total,
      'status': 'paid',
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final ledgerRef = _db.collection('ledger_entries').doc();
    batch.set(ledgerRef, {
      'direction': 'in',
      'category': serviceType,
      'amount': total,
      'vatAmount': vatAmount,
      'discountAmount': discountAmount,
      'referenceId': invoiceNumber,
      'orderId': orderId,
      'description': 'فاتورة $invoiceNumber - $customerName',
      'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (discountCode != null && discountCode.isNotEmpty) {
      final codeRef = _db.collection('discount_codes').doc(discountCode);
      batch.set(
        codeRef,
        {'usedCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    return invoiceNumber;
  }

  static Future<void> recordOutgoingPayment({
    required String category, // 'refund' | 'partner_payout' | 'expense'
    required double amount,
    required String description,
    String? orderId,
  }) async {
    await _db.collection('ledger_entries').add({
      'direction': 'out',
      'category': category,
      'amount': double.parse(amount.toStringAsFixed(2)),
      'orderId': orderId,
      'description': description,
      'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
