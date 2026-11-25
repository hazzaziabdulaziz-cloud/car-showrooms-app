import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/luxury_theme.dart';

class TowingHandoverSheet extends StatefulWidget {
  final String orderId;
  final String phase; // 'pickup' | 'delivery'

  const TowingHandoverSheet({
    super.key,
    required this.orderId,
    required this.phase,
  });

  static Future<bool?> show(BuildContext context, {required String orderId, required String phase}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TowingHandoverSheet(orderId: orderId, phase: phase),
    );
  }

  @override
  State<TowingHandoverSheet> createState() => _TowingHandoverSheetState();
}

class _TowingHandoverSheetState extends State<TowingHandoverSheet> {
  final List<String> _angles = const ['الواجهة الأمامية', 'الواجهة الخلفية', 'الجانب الأيمن', 'الجانب الأيسر'];
  final Map<String, String> _uploadedUrls = {};
  final Set<String> _uploadingAngles = {};
  final _picker = ImagePicker();
  bool _saving = false;

  bool get _allFourReady => _angles.every((a) => (_uploadedUrls[a] ?? '').isNotEmpty);

  Future<void> _pickAndUpload(String angle, int idx) async {
    setState(() => _uploadingAngles.add(angle));
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1600);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref()
          .child('towing_handovers/${widget.orderId}/${widget.phase}_${idx}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      if (mounted) setState(() => _uploadedUrls[angle] = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر رفع الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAngles.remove(angle));
    }
  }

  Future<void> _submitHandover() async {
    if (!_allFourReady) return;
    setState(() => _saving = true);
    try {
      final field = widget.phase == 'pickup' ? 'towing_pickup_photos' : 'towing_delivery_photos';
      final timeField = widget.phase == 'pickup' ? 'towing_pickup_at' : 'towing_delivery_at';

      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        field: _uploadedUrls,
        timeField: FieldValue.serverTimestamp(),
        'tow_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'towing_status': widget.phase == 'pickup' ? 'in_transit' : 'delivered_documented',
        'shipping_status': widget.phase == 'pickup' ? 'in_transit' : 'delivered',
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: LuxuryColors.success, content: Text('تم توثيق الصور الـ 4 بختم زمني رسمي بنجاح.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التوثيق: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.phase == 'pickup'
        ? 'توثيق استلام السيارة من المعرض (4 صور إلزامية)'
        : 'توثيق تسليم السيارة للمشتري (4 صور إلزامية)';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: LuxuryColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
          const SizedBox(height: 6),
          const Text('لا يمكن إغلاق المرحلة إلا بعد رفع صور الجهات الأربع لحماية السائق والعميل والمنصة.', style: TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
          const SizedBox(height: 14),
          ...List.generate(_angles.length, (idx) {
            final angle = _angles[idx];
            final done = (_uploadedUrls[angle] ?? '').isNotEmpty;
            final busy = _uploadingAngles.contains(angle);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(done ? Icons.check_circle : Icons.camera_alt_outlined, color: done ? LuxuryColors.success : LuxuryColors.textSecondary),
              title: Text(angle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              trailing: OutlinedButton(
                onPressed: busy ? null : () => _pickAndUpload(angle, idx),
                child: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(done ? 'تم الرفع ✓' : 'اختيار / تصوير'),
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
              onPressed: (_allFourReady && !_saving) ? _submitHandover : null,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: LuxuryColors.gold))
                  : const Text('اعتماد التوثيق وحفظ الختم الزمني', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
