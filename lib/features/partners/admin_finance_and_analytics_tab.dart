import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/analytics_and_accounting_service.dart';
import '../../core/app_error_shield.dart';

/// لوحة الأدمن الشاملة: الإحصائيات + سيستم الحسابات والفواتير + الخصومات + سجل الأخطاء
class AdminFinanceAndAnalyticsTab extends StatelessWidget {
  const AdminFinanceAndAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: const [
          TabBar(
            isScrollable: true,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(icon: Icon(Icons.bar_chart), text: 'الإحصائيات'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'الحسابات والفواتير'),
              Tab(icon: Icon(Icons.local_offer), text: 'الخصومات'),
              Tab(icon: Icon(Icons.shield_outlined), text: 'سجل الأخطاء'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AnalyticsSubTab(),
                _AccountingSubTab(),
                _DiscountsSubTab(),
                _ErrorLogsSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 1. تبويب الإحصائيات ====================
class _AnalyticsSubTab extends StatelessWidget {
  const _AnalyticsSubTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('analytics_summary')
          .doc('global')
          .snapshots(),
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
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) {
            final (title, count, icon, color) = cards[i];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
                    ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== 2. تبويب الحسابات والفواتير ====================
class _AccountingSubTab extends StatelessWidget {
  const _AccountingSubTab();

  void _showOutgoingDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'refund';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تسجيل مبلغ طالع (مصروف / استرجاع)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const [
                  DropdownMenuItem(value: 'refund', child: Text('استرجاع لعميل')),
                  DropdownMenuItem(value: 'partner_payout', child: Text('تحويل مستحقات معرض/شريك')),
                  DropdownMenuItem(value: 'expense', child: Text('مصروف تشغيلي')),
                ],
                onChanged: (v) => setSt(() => category = v ?? 'refund'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ (ريال)'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'البيان / الوصف'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
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
      stream: FirebaseFirestore.instance
          .collection('ledger_entries')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double totalIn = 0;
        double totalOut = 0;
        for (final d in docs) {
          final m = d.data();
          final amt = (m['amount'] as num?)?.toDouble() ?? 0;
          if (m['direction'] == 'in') {
            totalIn += amt;
          } else {
            totalOut += amt;
          }
        }
        final net = totalIn - totalOut;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _miniStat('الداخل', '${totalIn.toStringAsFixed(0)} ر.س', Colors.green),
                  const SizedBox(width: 8),
                  _miniStat('الطالع', '${totalOut.toStringAsFixed(0)} ر.س', Colors.red),
                  const SizedBox(width: 8),
                  _miniStat('الصافي', '${net.toStringAsFixed(0)} ر.س', Colors.indigo),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showOutgoingDialog(context),
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  label: const Text('تسجيل قيد طالع (استرجاع / تحويل / مصروف)'),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Text('لا توجد قيود مالية مسجلة بعد.'))
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final m = docs[i].data();
                        final isIn = m['direction'] == 'in';
                        final amt = (m['amount'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIn ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(
                              isIn ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIn ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(m['description']?.toString() ?? 'قيد مالي'),
                          subtitle: Text('التصنيف: ${m['category'] ?? '-'}'),
                          trailing: Text(
                            '${isIn ? '+' : '-'}${amt.toStringAsFixed(2)} ر.س',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isIn ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

// ==================== 3. تبويب الخصومات والكوبونات ====================
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
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'الكود (مثال: VIP20)'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'نوع الخصم'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية (%)')),
                    DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ريال)')),
                  ],
                  onChanged: (v) => setSt(() => type = v ?? 'percent'),
                ),
                TextField(
                  controller: valCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قيمة الخصم'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'نطاق الخدمة'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('جميع الخدمات')),
                    DropdownMenuItem(value: 'car', child: Text('حجز سيارة')),
                    DropdownMenuItem(value: 'inspection', child: Text('فحص شامل')),
                    DropdownMenuItem(value: 'flatbed', child: Text('سطحة')),
                    DropdownMenuItem(value: 'subscription', child: Text('اشتراك معرض')),
                  ],
                  onChanged: (v) => setSt(() => scope = v ?? 'all'),
                ),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الحد الأقصى للاستخدام'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
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
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateCouponDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('إنشاء كود خصم جديد'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('discount_codes')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('لا توجد أكواد خصم حالياً.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final m = d.data();
                  final active = m['active'] == true;
                  final label = m['type'] == 'percent'
                      ? '${m['value']}%'
                      : '${m['value']} ر.س';
                  return SwitchListTile(
                    value: active,
                    title: Text('${m['code']}  ($label)', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('النطاق: ${m['scope']} • الاستخدام: ${m['usedCount'] ?? 0}/${m['maxUses'] ?? 0}'),
                    onChanged: (v) {
                      d.reference.update({'active': v});
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==================== 4. تبويب سجل الأخطاء المعزولة ====================
class _ErrorLogsSubTab extends StatelessWidget {
  const _ErrorLogsSubTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('app_error_logs')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد أخطاء مسجلة — التطبيق يعمل بسلاسة.'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = docs[i].data();
            return ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: Colors.amber),
              title: Text(m['source']?.toString() ?? 'App', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                m['error']?.toString() ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }
}
