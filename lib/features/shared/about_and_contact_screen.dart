import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/app_core.dart';
import '../../core/luxury_theme.dart';

class AboutAndContactScreen extends StatefulWidget {
  final int initialSection;
  const AboutAndContactScreen({super.key, this.initialSection = 0});

  @override
  State<AboutAndContactScreen> createState() => _AboutAndContactScreenState();
}

class _AboutAndContactScreenState extends State<AboutAndContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _topic = 'استفسار عام عن الحجز';
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'uid': FirebaseAuth.instance.currentUser?.uid ?? 'guest',
        'name': SecurityGuard.sanitizeText(_nameCtrl.text, maxLength: 80),
        'phone': SecurityGuard.sanitizeText(_phoneCtrl.text, maxLength: 20),
        'topic': _topic,
        'message': SecurityGuard.sanitizeText(_msgCtrl.text, maxLength: 800),
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _msgCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: LuxuryColors.success, content: Text('تم استلام رسالتك بنجاح ✓ سيتواصل معك فريق دعم «شاري» قريباً.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxuryColors.background,
      appBar: AppBar(
        backgroundColor: LuxuryColors.navy,
        foregroundColor: Colors.white,
        title: const Text('من نحن · تواصل معنا', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: LuxuryColors.navy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('من نحن — منصة «شاري»', style: TextStyle(color: LuxuryColors.gold, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('شارع المعارض الرقمي الأول في المملكة العربية السعودية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.35)),
                    SizedBox(height: 10),
                    Text(
                      'وُلدت «شاري» لتنقل تجربة زيارة معارض ووكالات السيارات في مناطق المملكة الـ 13 إلى جوالك بشفافية وأمان كامل: توثيق رسمي للمعارض بشهادات الآيبان، فحص فني مستقل بـ 12 بنداً، شحن موثق بـ 4 صور عبر سطحات معتمدة، ونظام ضمان يحفظ حقوق الجميع.',
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.65),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _pillar(Icons.verified_user_outlined, 'معارض ووكالات موثقة', 'مطابقة السجل التجاري مع شهادة الآيبان البنكية.'),
                  _pillar(Icons.fact_check_outlined, 'فحص مستقل ومحايد', 'تقرير معتمد خلال 24 ساعة ونافذة اعتراض 24س / 50كم.'),
                  _pillar(Icons.local_shipping_outlined, 'شحن موثق لباب بيتك', 'سطحات في منطقتك مع توثيق 4 صور قبل التحميل والتسليم.'),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: LuxuryColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: LuxuryColors.border)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.support_agent_outlined, color: LuxuryColors.gold, size: 24),
                          SizedBox(width: 8),
                          Text('تواصل معنا — فريق خدمة العملاء والشركاء', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _nameCtrl, decoration: luxuryInput('الاسم الكامل', icon: Icons.person_outline), validator: (v) => SecurityGuard.validateRequiredText(v, 'الاسم'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: luxuryInput('رقم الجوال (05xxxxxxxx)', icon: Icons.phone_android), validator: (v) => SecurityGuard.validateRequiredText(v, 'رقم الجوال', min: 9, max: 15))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _topic,
                        decoration: luxuryInput('موضوع التواصل'),
                        items: const [
                          DropdownMenuItem(value: 'استفسار عام عن الحجز', child: Text('استفسار عام عن الحجز')),
                          DropdownMenuItem(value: 'شراكة معارض ووكالات', child: Text('شراكة معارض ووكالات')),
                          DropdownMenuItem(value: 'دعم فني أو بلاغ', child: Text('دعم فني أو بلاغ')),
                          DropdownMenuItem(value: 'اقتراح تطوير', child: Text('اقتراح تطوير')),
                        ],
                        onChanged: (v) { if (v != null) setState(() => _topic = v); },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _msgCtrl, maxLines: 4, decoration: luxuryInput('اكتب رسالتك هنا...'), validator: (v) => SecurityGuard.validateRequiredText(v, 'الرسالة', min: 5, max: 800)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _sending ? null : _submitTicket,
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: Text(_sending ? 'جاري الإرسال...' : 'إرسال الرسالة لفريق «شاري»', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillar(IconData icon, String title, String desc) {
    return SizedBox(
      width: 270,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: LuxuryColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxuryColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LuxuryColors.gold, size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: LuxuryColors.navy)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
