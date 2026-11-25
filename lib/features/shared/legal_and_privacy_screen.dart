import 'package:material_ui/material_ui.dart';
import '../../core/luxury_theme.dart';

class LegalAndPrivacyScreen extends StatelessWidget {
  const LegalAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxuryColors.background,
      appBar: AppBar(
        backgroundColor: LuxuryColors.navy,
        foregroundColor: Colors.white,
        title: const Text('الشروط والأحكام وسياسة الخصوصية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _section(
                '1) دور منصة «معرضي» كوسيط تقني',
                'تعمل منصة «معرضي» كوسيط تقني موثّق يربط بين المشترين ومعارض السيارات وفاحصي المركبات وكباتن السطحات في المملكة العربية السعودية. تقع المسؤولية التجارية ونقل الملكية على المعرض، والمسؤولية الفنية للتقرير على الفاحص المعتمد، ومسؤولية سلامة النقل على كابتن السطحة.',
              ),
              _section(
                '2) سياسة العربون والضمان ونافذة الاعتراض',
                '• يُحفظ عربون الجدية لحين تأكيد المعرض خلال ساعتين، ويُسترد تلقائياً بنسبة 100% في حال عدم توفر السيارة أو انتهاء المهلة.\n• يحق للمشتري فتح اعتراض رسمي خلال 24 ساعة أو 50 كم من الاستلام (أيهما أسبق) وتُحجز مستحقات الفاحص لمدة 48 ساعة لحماية الحقوق.',
              ),
              _section(
                '3) سياسة الخصوصية وحماية البيانات الشخصية (PDPL)',
                'تُحفظ بياناتك ومستنداتك في خوادم مخصصة داخل المملكة (me-central2) وفق نظام حماية البيانات الشخصية السعودي (PDPL). تُحفظ شهادات الآيبان بصلاحيات سرية للمعرض والإدارة فقط، ويمكنك طلب حذف حسابك وبياناتك الشخصية نهائياً في أي وقت من شاشة «حجوزاتي».',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LuxuryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LuxuryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13.5, color: LuxuryColors.textSecondary, height: 1.65)),
        ],
      ),
    );
  }
}
