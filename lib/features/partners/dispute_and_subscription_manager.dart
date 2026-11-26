import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

class SubscriptionAndAntiBypassGuard {
  static bool isShowroomSubscriptionActive(Map<String, dynamic> showroomData) {
    final ts = showroomData['subscription_expires_at'];
    if (ts == null) return true;
    if (ts is Timestamp) return ts.toDate().isAfter(DateTime.now());
    return false;
  }

  static String maskedShowroomContact(String phone, {required bool isOrderConfirmed}) {
    if (isOrderConfirmed) return phone;
    return 'يظهر الرقم المباشر بعد تأكيد الحجز داخل شاري';
  }
}

class AdminDisputeCenterTab extends StatelessWidget {
  const AdminDisputeCenterTab({super.key});

  String _arabicStatus(String status) {
    switch (status) {
      case 'open_escrow_frozen':
      case 'open':
      case 'pending':
        return 'طلب مفتوح — المبلغ مجمّد بانتظار القرار';
      case 'resolved_refunded_buyer':
        return 'تم قبول النزاع — استرداد للمشتري';
      case 'resolved_released':
        return 'تم رفض النزاع — تحرير المستحقات للفاحص';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  Color _statusColor(String status) {
    if (status == 'resolved_refunded_buyer') return const Color(0xFF067647);
    if (status == 'resolved_released' || status == 'rejected') return const Color(0xFFB42318);
    return const Color(0xFFB54708);
  }

  Future<void> _resolveDispute(String disputeId, String orderId, {required bool acceptBuyerRefund}) async {
    await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update({
      'status': acceptBuyerRefund ? 'resolved_refunded_buyer' : 'resolved_released',
      'resolved_at': FieldValue.serverTimestamp(),
    });
    if (orderId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'dispute_status': 'resolved',
        'escrow_frozen': false,
        'inspector_payout_status': acceptBuyerRefund ? 'cancelled_dispute' : 'released',
      });
    }
  }

  Future<void> _purgeDemoData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنظيف بيانات التجربة'),
        content: const Text('سيتم حذف جميع النزاعات والطلبات التجريبية نهائياً من قاعدة البيانات. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB42318), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف بيانات التجربة'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final fs = FirebaseFirestore.instance;
    int deleted = 0;
    for (final col in [
      'disputes', 'orders', 'buyer_leads', 'support_tickets',
      'cars', 'showrooms', 'inspectors', 'tow_drivers',
      'invoices', 'ledger_entries', 'transactions',
      'analytics_daily', 'analytics_events', 'analytics_summary',
      'app_error_logs', 'ratings', 'discount_codes'
    ]) {
      try {
        final snap = await fs.collection(col).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
          deleted++;
        }
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تنظيف $deleted سجل تجريبي بنجاح.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text('مركز النزاعات والطلبات المعلّقة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                onPressed: () => _purgeDemoData(context),
                icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Color(0xFFB42318)),
                label: const Text('حذف بيانات التجربة', style: TextStyle(color: Color(0xFFB42318), fontSize: 12)),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
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
                child: Center(child: Text('لا توجد نزاعات حالياً — قاعدة البيانات نظيفة.')),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d = (doc.data() as Map<String, dynamic>?) ?? {};
                final orderId = (d['order_id'] ?? '').toString();
                final status = (d['status'] ?? 'open_escrow_frozen').toString();
                final isOpen = status == 'open_escrow_frozen' || status == 'open' || status == 'pending';
                final badgeColor = _statusColor(status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'طلب رقم: ${d['order_code'] ?? doc.id}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف هذا السجل',
                              icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFB42318)),
                              onPressed: () => doc.reference.delete(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _arabicStatus(status),
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('قراءة العداد: ${d['odometer_km'] ?? '-'} كم  |  السبب: ${d['reason'] ?? 'غير محدد'}'),
                        if (isOpen) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF067647), foregroundColor: Colors.white),
                                  onPressed: () => _resolveDispute(doc.id, orderId, acceptBuyerRefund: true),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('قبول الطلب (استرداد للمشتري)'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _resolveDispute(doc.id, orderId, acceptBuyerRefund: false),
                                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFB42318)),
                                  label: const Text('رفض الطلب (تحرير للفاحص)', style: TextStyle(color: Color(0xFFB42318))),
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
        ),
      ],
    );
  }
}
