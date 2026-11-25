import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

class AccountDeletionService {
  static Future<void> confirmAndDeleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب نهائياً'),
        content: const Text(
          'وفقاً لنظام حماية البيانات الشخصية (PDPL)، سيتم حذف حسابك وبياناتك الشخصية نهائياً مع الاحتفاظ بسجلات الفواتير النظامية فقط دون بياناتك التعريفية. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB42318), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف النهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
        'email': null,
        'phone': null,
      }, SetOptions(merge: true));

      await user.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف حسابك بنجاح.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        final msg = e.code == 'requires-recent-login'
            ? 'لأمانك، يرجى تسجيل الخروج ثم الدخول مجدداً قبل حذف الحساب.'
            : 'تعذر حذف الحساب: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }
}
