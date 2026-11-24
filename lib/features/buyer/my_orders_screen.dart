import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/account_deletion_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  int _pageLimit = 20;

  Future<void> _cancelOrder(String docId, String currentStatus) async {
    final refundPolicy = currentStatus == 'pending_showroom'
        ? 'سيتم استرداد العربون كاملاً لعدم تأكيد المعرض بعد.'
        : 'سيتم إلغاء الطلب ومعالجة الاسترداد وفق سياسة المنصة (مع خصم رسوم الفحص إن تم تنفيذه).';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إلغاء الحجز'),
        content: Text(refundPolicy),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB42318), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'cancelled_by_buyer',
      'cancelled_at': FieldValue.serverTimestamp(),
    });
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
              decoration: const InputDecoration(labelText: 'قراءة العداد الحالية (كم)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'وصف العيب أو الاختلاف عن تقرير الفحص', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفع النزاع وتجميد الضمان'),
          ),
        ],
      ),
    );
    if (ok != true || reasonCtrl.text.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
                    icon: Icon(i < stars ? Icons.star : Icons.star_border, color: const Color(0xFFC5A059), size: 32),
                    onPressed: () => setS(() => stars = i + 1),
                  );
                }),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظاتك عن المعرض / الفاحص / السطحة', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال التقييم')),
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
        appBar: AppBar(title: const Text('حجوزاتي')),
        body: const Center(child: Text('يرجى تسجيل الدخول لمتابعة حجوزاتك وتقارير الفحص.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزاتي'),
        actions: [
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
          return ListView.builder(
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
              final status = (d['status'] ?? 'pending_showroom').toString();
              final showroomName = (d['showroom_name'] ?? 'المعرض').toString();
              final rated = d['buyer_rated'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$code · $car', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('الحالة: $status'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'pending_showroom' || status == 'confirmed')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('إلغاء الحجز'),
                              onPressed: () => _cancelOrder(id, status),
                            ),
                          if (status == 'completed' && d['dispute_status'] != 'open')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.gavel_outlined, size: 16),
                              label: const Text('فتح نزاع (24س/50كم)'),
                              onPressed: () => _openDisputeDialog(id, code),
                            ),
                          if (status == 'completed' && !rated)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.star_outline, size: 16),
                              label: const Text('تقييم الصفقة'),
                              onPressed: () => _openRatingDialog(id, showroomName),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
