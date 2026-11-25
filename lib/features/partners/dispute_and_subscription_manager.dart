import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

class SubscriptionAndAntiBypassGuard {
  /// فحص هل اشتراك المعرض سارٍ أم منتهٍ لتجميد ظهور سياراته تلقائياً
  static bool isShowroomSubscriptionActive(Map<String, dynamic> showroomData) {
    final ts = showroomData['subscription_expires_at'];
    if (ts == null) return true; // الحسابات الجديدة قبل أول دورة فوترة
    if (ts is Timestamp) {
      return ts.toDate().isAfter(DateTime.now());
    }
    return false;
  }

  /// إخفاء رقم المعرض المباشر قبل تأكيد الحجز لمنع الالتفاف (Anti-Bypass)
  static String maskedShowroomContact(String phone, {required bool isOrderConfirmed}) {
    if (isOrderConfirmed) return phone;
    return 'يظهر الرقم المباشر بعد تأكيد الحجز داخل معرضي';
  }
}

class AdminDisputeCenterTab extends StatelessWidget {
  const AdminDisputeCenterTab({super.key});

  Future<void> _resolveDispute(String disputeId, String orderId, {required bool releaseToInspector}) async {
    await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update({
      'status': releaseToInspector ? 'resolved_released' : 'resolved_refunded_buyer',
      'resolved_at': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'dispute_status': 'resolved',
      'escrow_frozen': false,
      'inspector_payout_status': releaseToInspector ? 'released' : 'cancelled_dispute',
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .orderBy('created_at', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('لا توجد نزاعات مفتوحة حالياً.')),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = (doc.data() as Map<String, dynamic>?) ?? {};
            final orderId = (d['order_id'] ?? '').toString();
            final status = (d['status'] ?? 'open_escrow_frozen').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('طلب: ${d['order_code']} · الحالة: $status', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('العداد: ${d['odometer_km']} كم | السبب: ${d['reason']}'),
                    if (status == 'open_escrow_frozen') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _resolveDispute(doc.id, orderId, releaseToInspector: false),
                              child: const Text('استرداد للمشتري'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _resolveDispute(doc.id, orderId, releaseToInspector: true),
                              child: const Text('تحرير مستحقات الفاحص'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
