import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'pricing_rules.dart';

class PartnerSubscriptionAndReferral {
  static final _fs = FirebaseFirestore.instance;

  /// فحص هل الشريك (فاحص أو سطحة) مؤهل لاستقبال الطلبات حالياً
  /// يعيد true دائماً في فترة الإطلاق المجانية، ويتحقق من الاشتراك فقط عند تفعيل مفتاح المدير
  static Future<bool> canPartnerReceiveOrders({
    required String partnerType, // 'inspector' أو 'tow'
    required Map partnerData,
  }) async {
    final settingsDoc = await _fs.collection('app_settings').doc('launch_mode').get();
    final settings = settingsDoc.data() ?? {};
    final paidEnabled = partnerType == 'inspector'
        ? settings['inspectors_paid_enabled'] == true
        : settings['towing_paid_enabled'] == true;
    if (!paidEnabled) return true; // فترة الإطلاق المجانية

    final expires = partnerData['subscription_expires_at'];
    if (expires is Timestamp) {
      return expires.toDate().isAfter(DateTime.now());
    }
    return false;
  }

  /// قيد مكافأة الإحالة (20 ر.س) تلقائياً في محفظة الكابتن/الفاحص فقط عند تحقق الشرطين:
  /// (1) توثيق المعرض، و(2) رفع 5 سيارات حقيقية على الأقل، ولم تُصرف من قبل
  static Future<bool> creditReferralIfEligible(String showroomId) async {
    final srRef = _fs.collection('showrooms').doc(showroomId);
    final srDoc = await srRef.get();
    final d = srDoc.data();
    if (d == null) return false;
    final refCode = (d['referral_code'] ?? '').toString().trim();
    if (refCode.isEmpty || d['is_verified'] != true || d['referral_paid'] == true) {
      return false;
    }
    final carsSnap = await _fs.collection('cars').where('showroom_id', isEqualTo: showroomId).get();
    if (carsSnap.docs.length < 5) return false;

    await srRef.update({
      'referral_paid': true,
      'referral_paid_at': FieldValue.serverTimestamp(),
    });
    await _fs.collection('ledger_entries').add({
      'type': 'partner_referral_bonus',
      'referral_code': refCode,
      'showroom_id': showroomId,
      'amount': PricingRules.showroomReferralReward,
      'note': 'مكافأة إحالة معرض موثّق رفع 5 سيارات (20 ر.س)',
      'created_at': FieldValue.serverTimestamp(),
    });
    return true;
  }
}

class PartnerLaunchPlanBanner extends StatelessWidget {
  final String partnerType; // 'inspector' أو 'tow'
  const PartnerLaunchPlanBanner({super.key, required this.partnerType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('app_settings').doc('launch_mode').snapshots(),
      builder: (context, snap) {
        final raw = snap.data?.data();
        final d = raw is Map ? raw : {};
        final paid = partnerType == 'inspector'
            ? d['inspectors_paid_enabled'] == true
            : d['towing_paid_enabled'] == true;
        final text = !paid
            ? 'فترة الإطلاق: التسجيل والاشتراك الشهري مجاني 100% حالياً (حصتك 80% صافية من كل طلب).'
            : (partnerType == 'inspector'
                ? 'الاشتراك الشهري: فاحص فردي 149 ر.س · مركز فحص معتمد 299 ر.س (حصتك 200 ر.س لكل فحص).'
                : 'الاشتراك الشهري: سطحة عادية 99 ر.س · هيدروليك VIP 199 ر.س · ناقلة متعددة 349 ر.س (حصتك 80%).');
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F0E4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC5A059)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0B192C)),
              ),
              Builder(
                builder: (ctx) {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  if (uid.isEmpty) return const SizedBox.shrink();
                  final myCode = 'SHARI-${uid.substring(0, uid.length >= 6 ? 6 : uid.length).toUpperCase()}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'كود الإحالة الخاص بك: $myCode (مكافأة 20 ر.س لكل معرض موثّق يرفع 5 سيارات)',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF7A540E), fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: myCode));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('تم نسخ كود الإحالة: $myCode')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 15, color: Color(0xFF0B192C)),
                          label: const Text('نسخ', style: TextStyle(fontSize: 12, color: Color(0xFF0B192C))),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
