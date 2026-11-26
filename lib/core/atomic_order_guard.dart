import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AtomicOrderGuard {
  static final _fs = FirebaseFirestore.instance;

  /// 1) قفل السيارة ذرياً لمنع الحجز المزدوج (Race Condition)
  static Future<void> reserveCarAtomically(String? carId) async {
    if (carId == null || carId.trim().isEmpty) return;
    final ref = _fs.collection('cars').doc(carId.trim());
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final status = (snap.data()?['status'] ?? 'available').toString();
      if (status != 'available') {
        throw Exception('عذراً، تم حجز هذه السيارة للتو من عميل آخر.');
      }
      tx.update(ref, {
        'status': 'reserved',
        'reserved_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 2) التحقق البرمجي من مهلة الاعتراض النظامية (24 ساعة) قبل فتح نزاع
  static Future<bool> isWithin24HourDisputeWindow(String orderId) async {
    final doc = await _fs.collection('orders').doc(orderId).get();
    final d = doc.data();
    if (d == null) return false;
    final ts = d['inspection_completed_at'] ?? d['completed_at'] ?? d['updated_at'];
    if (ts is Timestamp) {
      return DateTime.now().difference(ts.toDate()).inHours <= 24;
    }
    return true;
  }

  /// 3) قفل مهمة فحص أو رحلة سطحة لأول شريك يقبلها ذرياً (يمنع تضارب القبول)
  static Future<void> claimTaskAtomically({
    required String orderId,
    required String statusField,
    required String expectedStatus,
    required String nextStatus,
    required String assigneeUidField,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('يجب تسجيل الدخول أولاً.');
    final ref = _fs.collection('orders').doc(orderId);
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      if ((data[statusField] ?? '').toString() != expectedStatus) {
        throw Exception('سبقك شريك آخر لقبول هذا الطلب.');
      }
      tx.update(ref, {
        statusField: nextStatus,
        assigneeUidField: uid,
        '${assigneeUidField}_claimed_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 4) طلب ترقية باقة معرض (499 أساسية / 999 احترافية)
  static Future<void> requestPlanUpgrade(String showroomId, String planCode) async {
    await _fs.collection('showrooms').doc(showroomId).update({
      'requested_plan': planCode,
      'plan_requested_at': FieldValue.serverTimestamp(),
    });
  }

  /// 5) اعتماد وتفعيل باقة معرض من لوحة المدير لمدة 30 يوماً
  static Future<void> adminActivatePlan(String showroomId, String planCode) async {
    final expires = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
    await _fs.collection('showrooms').doc(showroomId).update({
      'subscription_plan': planCode,
      'subscription_expires_at': planCode == 'free' ? null : expires,
      'is_prime_spot': planCode == 'pro',
      'requested_plan': FieldValue.delete(),
    });
  }
}
