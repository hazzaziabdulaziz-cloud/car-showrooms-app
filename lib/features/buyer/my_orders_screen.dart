import '../../core/atomic_order_guard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/account_deletion_service.dart';
import '../../core/luxury_theme.dart';
import 'order_tracking_sheet.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  int _pageLimit = 20;

  String _statusArabic(String status) {
    switch (status) {
      case 'paid_waiting_showroom':
      case 'pending_showroom':
        return 'بانتظار تأكيد المعرض (مهلة ساعتين)';
      case 'confirmed':
        return 'تم تأكيد التوفر ✓ — اختر الفحص أو السطحة';
      case 'path_selected':
        return 'جاري تنفيذ المسار المختار';
      case 'completed':
        return 'مكتمل — تم التسليم ✓';
      case 'sold_in_showroom_refunded':
        return 'انباعت في الصالة — استُرجع العربون';
      case 'cancelled_after_confirm':
        return 'ملغى من المعرض — استرداد العربون 100%';
      case 'cancelled_financing_rejected':
        return 'رفض تمويل بنكي — استرداد العربون 100%';
      case 'pending_admin_forfeit_review':
        return 'بانتظار مراجعة الإدارة للعربون';
      case 'cancelled_forfeited_70_30':
        return 'ملغى بعد التأكيد — العربون غير مسترد (70% معرض / 30% منصة)';
      case 'cancelled_refunded_100':
        return 'ملغى — تم استرداد العربون 100%';
      case 'cancelled_by_buyer':
      case 'cancelled_by_buyer_after_inspection':
        return 'ملغى من المشتري';
      case 'expired_no_showroom_reply':
        return 'انتهت مهلة المعرض — استرجاع تلقائي';
      default:
        return status;
    }
  }

  Future<void> _cancelOrder(String docId, String currentStatus, String carId) async {
    final waitingShowroom = currentStatus == 'paid_waiting_showroom' || (currentStatus == 'pending_showroom' || currentStatus == 'paid_waiting_showroom');
    final refundPolicy = waitingShowroom
        ? 'سيتم إلغاء الحجز واسترداد العربون كاملاً 100% لأن المعرض لم يؤكد توفر السيارة بعد.'
        : 'تنبيه مهم: تم تأكيد توفر السيارة وتجميدها من المعرض بالفعل؛ في حال إلغائك الآن بدون عيب في الفحص لن يُسترد العربون (70% للمعرض تعويضاً عن تجميد السيارة و30% رسوم خدمة للمنصة وفق إقرار الأمانة). هل تؤكد الإلغاء؟';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إلغاء الحجز'),
        content: Text(refundPolicy),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LuxuryColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(waitingShowroom ? 'تأكيد الإلغاء' : 'أوافق على الإلغاء بدون استرداد'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': waitingShowroom ? 'cancelled_by_buyer' : 'cancelled_forfeited_70_30',
      'refund_decision': waitingShowroom ? 'refund_buyer_100' : 'forfeited_by_buyer_cancel_70_30',
      'cancelled_at': FieldValue.serverTimestamp(),
    });
    if (carId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('cars').doc(carId).update({'status': 'available'});
      } catch (_) {}
    }
  }

  Future<void> _openDisputeDialog(String docId, String orderCode) async {
    final reasonCtrl = TextEditingController();
    final odometerCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('فتح نزاع (نافذة 24 ساعة / 50 كم) · $orderCode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: odometerCtrl,
              keyboardType: TextInputType.number,
              decoration: luxuryInput('قراءة العداد الحالية (كم)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: luxuryInput('وصف العيب أو الاختلاف عن تقرير الفحص'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LuxuryColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفع النزاع وتجميد الضمان'),
          ),
        ],
      ),
    );
    if (ok != true || reasonCtrl.text.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final allowed24h = await AtomicOrderGuard.isWithin24HourDisputeWindow(docId);
    if (!allowed24h) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('انتهت مهلة الاعتراض النظامية (24 ساعة من التسليم/الفحص) ولا يمكن فتح نزاع جديد.'),
            backgroundColor: Color(0xFFB42318),
          ),
        );
      }
      return;
    }
    await FirebaseFirestore.instance.collection('disputes').add({
      'order_id': docId,
      'order_code': orderCode,
      'buyer_uid': uid,
      'odometer_km': odometerCtrl.text.trim(),
      'reason': reasonCtrl.text.trim(),
      'status': 'open_escrow_frozen',
      'created_at': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'dispute_status': 'open',
      'escrow_frozen': true,
    });
  }

  Future<void> _openRatingDialog(String docId, String showroomName) async {
    int stars = 5;
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تقييم الصفقة · $showroomName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(i < stars ? Icons.star : Icons.star_border, color: LuxuryColors.gold, size: 32),
                    onPressed: () => setS(() => stars = i + 1),
                  );
                }),
              ),
              TextField(
                controller: noteCtrl,
                decoration: luxuryInput('ملاحظاتك عن المعرض / الفاحص / السطحة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال التقييم'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance.collection('ratings').add({
      'order_id': docId,
      'buyer_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      'stars': stars,
      'comment': noteCtrl.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({'buyer_rated': true});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: LuxuryColors.background,
        appBar: AppBar(
          backgroundColor: LuxuryColors.navy,
          foregroundColor: Colors.white,
          title: const Text('حجوزاتي'),
          actions: [
            TextButton.icon(
              onPressed: () => OrderTrackingSheet.show(context),
              icon: const Icon(Icons.search, color: LuxuryColors.gold, size: 18),
              label: const Text('تتبع برقم الحجز', style: TextStyle(color: LuxuryColors.gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: const Center(child: Text('يرجى تسجيل الدخول لمتابعة حجوزاتك وتقارير الفحص.')),
      );
    }

    return Scaffold(
      backgroundColor: LuxuryColors.background,
      appBar: AppBar(
        backgroundColor: LuxuryColors.navy,
        foregroundColor: Colors.white,
        title: const Text('حجوزاتي ومتابعة الطلبات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
        actions: [
          IconButton(
            tooltip: 'تتبع برقم الحجز',
            icon: const Icon(Icons.qr_code_scanner, color: LuxuryColors.gold),
            onPressed: () => OrderTrackingSheet.show(context),
          ),
          IconButton(
            tooltip: 'حذف الحساب (PDPL)',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => AccountDeletionService.confirmAndDeleteAccount(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('buyer_uid', isEqualTo: user.uid)
            .orderBy('created_at', descending: true)
            .limit(_pageLimit)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد حجوزات مرتبطة بحسابك حالياً.'));
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                itemBuilder: (context, i) {
                  if (i == docs.length) {
                    return docs.length >= _pageLimit
                        ? TextButton(
                            onPressed: () => setState(() => _pageLimit += 20),
                            child: const Text('تحميل المزيد من الحجوزات'),
                          )
                        : const SizedBox.shrink();
                  }
                  final d = (docs[i].data() as Map<String, dynamic>?) ?? {};
                  final id = docs[i].id;
                  final code = (d['order_code'] ?? id).toString();
                  final car = (d['car_title'] ?? 'سيارة').toString();
                  final status = (d['status'] ?? 'paid_waiting_showroom').toString();
                  final showroomName = (d['showroom_name'] ?? 'المعرض').toString();
                  final phoneLast4 = (d['buyer_phone_last4'] ?? '').toString();
                  final pin = (d['handover_pin'] ?? '---').toString();
                  final rated = d['buyer_rated'] == true;
                  final canCancel = status == 'paid_waiting_showroom' || status == 'pending_showroom' || status == 'confirmed';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: LuxuryColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: LuxuryColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('$code · $car', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: LuxuryColors.navy)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: LuxuryColors.goldSoft, borderRadius: BorderRadius.circular(8)),
                              child: Text('كود التسليم: $pin', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('المعرض: $showroomName', style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          _statusArabic(status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: status == 'completed' ? LuxuryColors.success : LuxuryColors.navy,
                          ),
                        ),
                        const Divider(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
                              icon: const Icon(Icons.track_changes_outlined, size: 16),
                              label: const Text('متابعة التفاصيل / الفحص / السطحة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                              onPressed: () => OrderTrackingSheet.show(
                                context,
                                initialOrderCode: code,
                                initialPhoneLast4: phoneLast4,
                              ),
                            ),
                            if (canCancel)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: LuxuryColors.danger, side: const BorderSide(color: LuxuryColors.danger)),
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('إلغاء الحجز'),
                                onPressed: () => _cancelOrder(id, status, (d['car_id'] ?? '').toString()),
                              ),
                            if (status == 'completed' && d['dispute_status'] != 'open')
                              OutlinedButton.icon(
                                icon: const Icon(Icons.gavel_outlined, size: 16),
                                label: const Text('فتح نزاع (24س/50كم)'),
                                onPressed: () => _openDisputeDialog(id, code),
                              ),
                            if (status == 'completed' && !rated)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: LuxuryColors.gold, foregroundColor: LuxuryColors.navy),
                                icon: const Icon(Icons.star_outline, size: 16),
                                label: const Text('تقييم الصفقة'),
                                onPressed: () => _openRatingDialog(id, showroomName),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
