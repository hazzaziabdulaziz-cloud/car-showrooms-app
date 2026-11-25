import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/analytics_and_accounting_service.dart';
import '../../core/app_error_shield.dart';
import '../../core/luxury_theme.dart';

/// لوحة الأدمن الشاملة بدون تمرير مزدوج (تمرير واحد سلس مع الصفحة)
class AdminFinanceAndAnalyticsTab extends StatefulWidget {
  const AdminFinanceAndAnalyticsTab({super.key});

  @override
  State<AdminFinanceAndAnalyticsTab> createState() => _AdminFinanceAndAnalyticsTabState();
}

class _AdminFinanceAndAnalyticsTabState extends State<AdminFinanceAndAnalyticsTab> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (0, 'الإحصائيات', Icons.bar_chart),
      (1, 'الحسابات والفواتير', Icons.account_balance_wallet),
      (2, 'الخصومات', Icons.local_offer),
      (3, 'سجل الأخطاء', Icons.shield_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tabs.map((t) {
            final active = _tab == t.$1;
            return ChoiceChip(
              avatar: Icon(t.$3, size: 16, color: active ? LuxuryColors.gold : LuxuryColors.navy),
              label: Text(t.$2),
              selected: active,
              selectedColor: LuxuryColors.navy,
              backgroundColor: LuxuryColors.surface,
              labelStyle: TextStyle(color: active ? LuxuryColors.gold : LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 12.5),
              onSelected: (_) => setState(() => _tab = t.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_tab == 0) const _AnalyticsSubTab(),
        if (_tab == 1) const _AccountingSubTab(),
        if (_tab == 2) const _DiscountsSubTab(),
        if (_tab == 3) const _ErrorLogsSubTab(),
      ],
    );
  }
}

class _AnalyticsSubTab extends StatelessWidget {
  const _AnalyticsSubTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('analytics_summary').doc('global').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        int val(String k) => (data[k] as num?)?.toInt() ?? 0;

        final cards = [
          ('فتحات التطبيق', val(AnalyticsAndAccountingService.evAppOpen), Icons.phone_android, Colors.indigo),
          ('تصفح المعارض', val(AnalyticsAndAccountingService.evBrowseShowroom), Icons.storefront, Colors.teal),
          ('تصفح السيارات', val(AnalyticsAndAccountingService.evBrowseCar), Icons.directions_car, Colors.blue),
          ('حجوزات السيارات', val(AnalyticsAndAccountingService.evBookCar), Icons.car_rental, Colors.green),
          ('حجوزات السطحات', val(AnalyticsAndAccountingService.evBookFlatbed), Icons.local_shipping, Colors.orange),
          ('حجوزات الفحص', val(AnalyticsAndAccountingService.evBookInspection), Icons.fact_check, Colors.purple),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) {
            final (title, count, icon, color) = cards[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LuxuryColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LuxuryColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 6),
                  Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AccountingSubTab extends StatelessWidget {
  const _AccountingSubTab();

  String _categoryArabic(String cat) {
    switch (cat) {
      case 'car_booking':
        return 'عربون سيارة (أمانة للمعرض)';
      case 'inspection':
        return 'فحص شامل (20% إيراد منصة · 80% أمانة فاحص)';
      case 'flatbed':
        return 'شحن سطحة (10% إيراد منصة · 90% أمانة سطحة)';
      case 'subscription':
        return 'اشتراك معرض (إيراد منصة 100%)';
      case 'partner_payout':
        return 'تحويل مستحقات شريك (فاحص / سطحة / معرض)';
      case 'refund':
        return 'استرداد مبلغ لعميل';
      case 'expense':
        return 'مصروف تشغيلي للمنصة';
      default:
        return cat;
    }
  }

  void _showOutgoingDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'partner_payout';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تسجيل قيد طالع (تحويل / استرجاع / مصروف)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: luxuryInput('النوع'),
                items: const [
                  DropdownMenuItem(value: 'partner_payout', child: Text('تحويل مستحقات شريك (من الأمانات)')),
                  DropdownMenuItem(value: 'refund', child: Text('استرجاع لعميل (من الأمانات)')),
                  DropdownMenuItem(value: 'expense', child: Text('مصروف تشغيلي (يخصم من إيراد المنصة)')),
                ],
                onChanged: (v) => setSt(() => category = v ?? 'partner_payout'),
              ),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: luxuryInput('المبلغ (ريال)')),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: luxuryInput('البيان / الوصف')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                Navigator.pop(ctx);
                await AppErrorShield.runSafe(context, () async {
                  await AnalyticsAndAccountingService.recordOutgoingPayment(
                    category: category,
                    amount: amt,
                    description: descCtrl.text.trim().isEmpty ? 'قيد صرف يدوي' : descCtrl.text.trim(),
                  );
                });
              },
              child: const Text('حفظ القيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('ledger_entries').orderBy('createdAt', descending: true).limit(100).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double platformRevenue = 0;
        double escrowBalance = 0;
        double totalGmv = 0;

        for (final d in docs) {
          final m = d.data();
          final amt = (m['amount'] as num?)?.toDouble() ?? 0;
          final dir = (m['direction'] ?? 'in').toString();
          final cat = (m['category'] ?? '').toString();

          if (dir == 'in') {
            totalGmv += amt;
            if (cat == 'subscription') {
              platformRevenue += amt;
            } else if (cat == 'inspection') {
              platformRevenue += amt * 0.20;
              escrowBalance += amt * 0.80;
            } else if (cat == 'flatbed') {
              platformRevenue += amt * 0.10;
              escrowBalance += amt * 0.90;
            } else {
              // عربون سيارة يُحفظ كأمانة للمعرض
              escrowBalance += amt;
            }
          } else {
            if (cat == 'expense') {
              platformRevenue -= amt;
            } else {
              // تحويل مستحقات شريك أو استرجاع عميل يُخصم من الأمانات
              escrowBalance -= amt;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _miniStat('صافي إيراد المنصة', '${platformRevenue.toStringAsFixed(0)} ر.س', LuxuryColors.success),
                const SizedBox(width: 8),
                _miniStat('أمانات ومستحقات الشركاء', '${escrowBalance.toStringAsFixed(0)} ر.س', LuxuryColors.navy),
                const SizedBox(width: 8),
                _miniStat('إجمالي التدفق (GMV)', '${totalGmv.toStringAsFixed(0)} ر.س', Colors.indigo),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'ملاحظة محاسبية: 90% من السطحة و80% من الفحص وعربون السيارة تُقيّد كأمانات للشركاء ولا تُحسب إيراداً للمنصة.',
              style: TextStyle(fontSize: 11.5, color: LuxuryColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showOutgoingDialog(context),
              icon: const Icon(Icons.remove_circle_outline, color: LuxuryColors.danger),
              label: const Text('تسجيل قيد طالع (تحويل شريك / استرجاع / مصروف)'),
            ),
            const Divider(height: 24),
            if (docs.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد قيود مالية مسجلة بعد.')))
            else
              ...docs.map((doc) {
                final m = doc.data();
                final isIn = m['direction'] == 'in';
                final amt = (m['amount'] as num?)?.toDouble() ?? 0;
                final cat = (m['category'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LuxuryColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LuxuryColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isIn ? LuxuryColors.successBg : const Color(0xFFFEF3F2),
                        child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? LuxuryColors.success : LuxuryColors.danger, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['description']?.toString() ?? 'قيد مالي', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            Text(_categoryArabic(cat), style: const TextStyle(fontSize: 11.5, color: LuxuryColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        '${isIn ? '+' : '-'}${amt.toStringAsFixed(2)} ر.س',
                        style: TextStyle(fontWeight: FontWeight.w800, color: isIn ? LuxuryColors.success : LuxuryColors.danger),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LuxuryColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DiscountsSubTab extends StatelessWidget {
  const _DiscountsSubTab();

  void _showCreateCouponDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '100');
    String type = 'percent';
    String scope = 'all';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إنشاء كود خصم جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: luxuryInput('الكود (مثال: VIP20)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: luxuryInput('نوع الخصم'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية (%)')),
                    DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ريال)')),
                  ],
                  onChanged: (v) => setSt(() => type = v ?? 'percent'),
                ),
                const SizedBox(height: 10),
                TextField(controller: valCtrl, keyboardType: TextInputType.number, decoration: luxuryInput('قيمة الخصم')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: luxuryInput('نطاق الخدمة'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('جميع الخدمات')),
                    DropdownMenuItem(value: 'car', child: Text('حجز سيارة')),
                    DropdownMenuItem(value: 'inspection', child: Text('فحص شامل')),
                    DropdownMenuItem(value: 'flatbed', child: Text('سطحة')),
                    DropdownMenuItem(value: 'subscription', child: Text('اشتراك معرض')),
                  ],
                  onChanged: (v) => setSt(() => scope = v ?? 'all'),
                ),
                const SizedBox(height: 10),
                TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: luxuryInput('الحد الأقصى للاستخدام (0 = مفتوح)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold),
              onPressed: () async {
                final code = codeCtrl.text.trim();
                final val = double.tryParse(valCtrl.text.trim()) ?? 0;
                final maxUses = int.tryParse(maxCtrl.text.trim()) ?? 100;
                if (code.isEmpty || val <= 0) return;
                Navigator.pop(ctx);
                await AppErrorShield.runSafe(context, () async {
                  await AnalyticsAndAccountingService.createDiscountCode(
                    code: code,
                    type: type,
                    value: val,
                    scope: scope,
                    maxUses: maxUses,
                  );
                });
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => _showCreateCouponDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('إنشاء كود خصم جديد', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        StreamBuilder(
          stream: FirebaseFirestore.instance.collection('discount_codes').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد أكواد خصم حالياً.')));
            return Column(
              children: docs.map((d) {
                final m = d.data();
                final active = m['active'] == true;
                final label = m['type'] == 'percent' ? '${m['value']}%' : '${m['value']} ر.س';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: LuxuryColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LuxuryColors.border),
                  ),
                  child: SwitchListTile(
                    value: active,
                    title: Text('${m['code']} ($label)', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('النطاق: ${m['scope']} • الاستخدام: ${m['usedCount'] ?? 0}/${m['maxUses'] ?? 0}'),
                    onChanged: (v) => d.reference.update({'active': v}),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ErrorLogsSubTab extends StatelessWidget {
  const _ErrorLogsSubTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('app_error_logs').orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد أخطاء مسجلة — التطبيق يعمل بسلاسة.')));
        }
        return Column(
          children: docs.map((doc) {
            final m = doc.data();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: LuxuryColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LuxuryColors.border)),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_outlined, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['source']?.toString() ?? 'App', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(m['error']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
