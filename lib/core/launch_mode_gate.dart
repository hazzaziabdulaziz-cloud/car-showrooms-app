import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'admin_config.dart';

class LaunchModeService {
  static DocumentReference get settingsRef =>
      FirebaseFirestore.instance.collection('app_settings').doc('launch_mode');

  static Stream<DocumentSnapshot> watchSettingsDoc() => settingsRef.snapshots();

  static Future<void> setFlag(String key, bool value) async {
    await settingsRef.set({key: value, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}

class StealthFoundingGate extends StatefulWidget {
  final Widget child;
  final VoidCallback onOpenPartners;

  const StealthFoundingGate({
    super.key,
    required this.child,
    required this.onOpenPartners,
  });

  @override
  State<StealthFoundingGate> createState() => _StealthFoundingGateState();
}

class _StealthFoundingGateState extends State<StealthFoundingGate> {
  final _phoneCtrl = TextEditingController();
  bool _savingWaitlist = false;
  bool _joinedWaitlist = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinWaitlist() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم جوال صحيح (مثال: 05XXXXXXXX).')),
      );
      return;
    }
    setState(() => _savingWaitlist = true);
    try {
      await FirebaseFirestore.instance.collection('waitlist_leads').add({
        'phone': phone,
        'coupon_code': 'SHARI50',
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _joinedWaitlist = true);
        _phoneCtrl.clear();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _savingWaitlist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: LaunchModeService.watchSettingsDoc(),
      builder: (context, snap) {
        final raw = snap.data?.data();
        final data = raw is Map ? raw : {};
        final stealthOn = data['stealth_founding_mode'] == true;
        final isAdmin = isAdminEmail(FirebaseAuth.instance.currentUser?.email);
        if (!stealthOn || isAdmin) {
          return widget.child;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B192C),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFC5A059), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset('assets/app_icon.png', width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'بوابة الشركاء المؤسسين — منصة شاري',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFC5A059)),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'نجهّز الآن شبكة المعارض والوكالات المعتمدة والفاحصين وكباتن السطحات قبل الافتتاح العام للمشترين في المملكة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x1AC5A059),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x66C5A059)),
                          ),
                          child: const Text(
                            'عرض الإطلاق المبكر الحصري:\n• الباقة الاحترافية للمعارض (999 ر.س) مجاناً لمدة 3 شهور.\n• تسجيل مجاني 100% للفاحصين وكباتن السطحات (حصة 80% صافية).',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5, height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC5A059),
                              foregroundColor: const Color(0xFF0B192C),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: widget.onOpenPartners,
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('سجّل معرضك أو انضم كفاحص / سطحة الآن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'مشتري سيارة؟ احجز مقعدك في قائمة الانتظار',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0B192C)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'سجّل رقم جوالك ليصلك تنبيه لحظة الافتتاح + كود خصم 50 ر.س على أول فحص (SHARI50).',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
                        ),
                        const SizedBox(height: 10),
                        if (_joinedWaitlist)
                          const Text('تم تسجيلك في قائمة الانتظار بنجاح! كودك المحجوز: SHARI50', style: TextStyle(color: Color(0xFF067647), fontWeight: FontWeight.w700))
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: '05XXXXXXXX',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C), foregroundColor: Colors.white),
                                onPressed: _savingWaitlist ? null : _joinWaitlist,
                                child: Text(_savingWaitlist ? '...' : 'احجز الخصم'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminLaunchControlsCard extends StatelessWidget {
  const AdminLaunchControlsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: LaunchModeService.watchSettingsDoc(),
      builder: (context, snap) {
        final raw = snap.data?.data();
        final d = raw is Map ? raw : {};
        final stealth = d['stealth_founding_mode'] == true;
        final inspPaid = d['inspectors_paid_enabled'] == true;
        final towPaid = d['towing_paid_enabled'] == true;
        return Card(
          color: const Color(0xFFF8F6F1),
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFC5A059)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مفاتيح الإطلاق واشتراكات الشركاء (تحكم المدير)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0B192C))),
                SwitchListTile(
                  dense: true,
                  title: const Text('وضع الإطلاق الصامت (بوابة المعارض المؤسسة فقط)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('يخفي التصفح العام والأصفار عن غير المدير ويوجه الشركاء للتسجيل + قائمة الانتظار.', style: TextStyle(fontSize: 11.5)),
                  value: stealth,
                  onChanged: (v) => LaunchModeService.setFlag('stealth_founding_mode', v),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('تفعيل الاشتراك الشهري للفاحصين (149 / 299 ر.س)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('معطّل = مجاني 100% في فترة الإطلاق الأولي.', style: TextStyle(fontSize: 11.5)),
                  value: inspPaid,
                  onChanged: (v) => LaunchModeService.setFlag('inspectors_paid_enabled', v),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('تفعيل الاشتراك الشهري للسطحات (99 / 199 / 349 ر.س)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('معطّل = مجاني 100% في فترة الإطلاق الأولي.', style: TextStyle(fontSize: 11.5)),
                  value: towPaid,
                  onChanged: (v) => LaunchModeService.setFlag('towing_paid_enabled', v),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
