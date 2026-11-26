import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

class BuyerFavoritesStore {
  static final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>({});

  static Future<void> toggle(String carId) async {
    final next = Set<String>.from(ids.value);
    final added = !next.contains(carId);
    if (added) {
      next.add(carId);
    } else {
      next.remove(carId);
    }
    ids.value = next;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'favorite_cars': next.toList(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}

class FavoriteHeartButton extends StatelessWidget {
  final String carId;
  const FavoriteHeartButton({super.key, required this.carId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: BuyerFavoritesStore.ids,
      builder: (context, favs, _) {
        final isFav = favs.contains(carId);
        return IconButton(
          tooltip: isFav ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? const Color(0xFFB42318) : const Color(0xFF475467),
            size: 20,
          ),
          onPressed: () async {
            await BuyerFavoritesStore.toggle(carId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(isFav ? 'تمت إزالة السيارة من المفضلة.' : 'تم حفظ السيارة في المفضلة.'),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class OrderRatingCard extends StatefulWidget {
  final String orderId;
  final String showroomId;
  final String showroomName;

  const OrderRatingCard({
    super.key,
    required this.orderId,
    required this.showroomId,
    required this.showroomName,
  });

  @override
  State<OrderRatingCard> createState() => _OrderRatingCardState();
}

class _OrderRatingCardState extends State<OrderRatingCard> {
  int _stars = 5;
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('ratings').add({
        'order_id': widget.orderId,
        'showroom_id': widget.showroomId,
        'showroom_name': widget.showroomName,
        'buyer_uid': uid,
        'stars': _stars,
        'note': _noteCtrl.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
      if (widget.showroomId.isNotEmpty && widget.showroomId != 'general') {
        final all = await FirebaseFirestore.instance
            .collection('ratings')
            .where('showroom_id', isEqualTo: widget.showroomId)
            .get();
        if (all.docs.isNotEmpty) {
          final total = all.docs.fold<double>(0, (acc, d) => acc + ((d.data()['stars'] as num?)?.toDouble() ?? 5));
          final avg = double.parse((total / all.docs.length).toStringAsFixed(1));
          await FirebaseFirestore.instance.collection('showrooms').doc(widget.showroomId).update({'rating': avg});
        }
      }
      if (mounted) setState(() => _submitted = true);
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF067647)),
        ),
        child: const Text('شكراً لك! تم حفظ تقييمك وتحديث تقييم المعرض بنجاح.', style: TextStyle(color: Color(0xFF067647), fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC5A059)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('قيّم تجربتك مع ${widget.showroomName}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0B192C), fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final idx = i + 1;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                icon: Icon(idx <= _stars ? Icons.star : Icons.star_border, color: const Color(0xFFC5A059), size: 28),
                onPressed: () => setState(() => _stars = idx),
              );
            }),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              hintText: 'ملاحظة اختيارية حول المعرض أو الفحص أو التوصيل...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C), foregroundColor: Colors.white),
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'جاري الإرسال...' : 'إرسال التقييم ($_stars / 5)'),
            ),
          ),
        ],
      ),
    );
  }
}
