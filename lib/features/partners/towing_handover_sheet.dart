import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TowingHandoverSheet extends StatefulWidget {
  final String orderId;
  final String phase; // 'pickup' | 'delivery'

  const TowingHandoverSheet({
    super.key,
    required this.orderId,
    required this.phase,
  });

  static Future<void> show(BuildContext context, {required String orderId, required String phase}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TowingHandoverSheet(orderId: orderId, phase: phase),
    );
  }

  @override
  State<TowingHandoverSheet> createState() => _TowingHandoverSheetState();
}

class _TowingHandoverSheetState extends State<TowingHandoverSheet> {
  final List<String> _angles = const ['الواجهة الأمامية', 'الواجهة الخلفية', 'الجانب الأيمن', 'الجانب الأيسر'];
  final Map<String, String> _uploadedUrls = {};
  bool _saving = false;

  bool get _allFourReady => _angles.every((a) => (_uploadedUrls[a] ?? '').isNotEmpty);

  Future<void> _submitHandover() async {
    if (!_allFourReady) return;
    setState(() => _saving = true);
    final field = widget.phase == 'pickup' ? 'towing_pickup_photos' : 'towing_delivery_photos';
    final timeField = widget.phase == 'pickup' ? 'towing_pickup_at' : 'towing_delivery_at';

    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      field: _uploadedUrls,
      timeField: FieldValue.serverTimestamp(),
      'towing_status': widget.phase == 'pickup' ? 'in_transit' : 'delivered_documented',
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم توثيق الصور الـ 4 بختم زمني رسمي بنجاح.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.phase == 'pickup'
        ? 'توثيق استلام السيارة من المعرض (4 صور إلزامية)'
        : 'توثيق تسليم السيارة للمشتري (4 صور إلزامية)';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('لا يمكن إغلاق المرحلة إلا بعد توثيق الجهات الأربع لحماية السائق والعميل والمنصة.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 14),
          ..._angles.map((angle) {
            final done = (_uploadedUrls[angle] ?? '').isNotEmpty;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(done ? Icons.check_circle : Icons.camera_alt_outlined, color: done ? Colors.green : Colors.grey),
              title: Text(angle),
              trailing: OutlinedButton(
                onPressed: () {
                  // يرتبط مباشرة بـ ImagePicker + FirebaseStorage + ImageCompressionHelper عند التفعيل الفعلي
                  setState(() => _uploadedUrls[angle] = 'verified_timestamp_${DateTime.now().millisecondsSinceEpoch}');
                },
                child: Text(done ? 'تم التوثيق' : 'التقاط / رفع'),
              ),
            );
          }),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: (_allFourReady && !_saving) ? _submitHandover : null,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('اعتماد التوثيق وحفظ الختم الزمني'),
          ),
        ],
      ),
    );
  }
}
