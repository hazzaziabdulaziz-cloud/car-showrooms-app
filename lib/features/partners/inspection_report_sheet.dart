import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/luxury_theme.dart';

class InspectionReportSheet extends StatefulWidget {
  final DocumentReference orderRef;
  final String orderCode;
  final String carTitle;

  const InspectionReportSheet({
    super.key,
    required this.orderRef,
    required this.orderCode,
    required this.carTitle,
  });

  static Future show(
    BuildContext context, {
    required DocumentReference orderRef,
    required String orderCode,
    required String carTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InspectionReportSheet(
        orderRef: orderRef,
        orderCode: orderCode,
        carTitle: carTitle,
      ),
    );
  }

  @override
  State<InspectionReportSheet> createState() => _InspectionReportSheetState();
}

class _InspectionReportSheetState extends State<InspectionReportSheet> {
  String _engine = 'سليم 100%';
  String _gear = 'سليم 100%';
  String _chassis = 'سليم وكالة';
  String _body = 'بودي وكالة بالكامل';
  String _airbags = 'سليمة (لم تخرج)';
  String _acAndSusp = 'ممتازة';

  final _odometerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _repairCostCtrl = TextEditingController(text: '0');
  String _obdStatus = 'سليم بدون أكواد عطل (OBD-II)';
  String _tiresBrakes = 'جديدة / ممتازة';
  String _interiorKeys = 'نظيفة وكالة + مفتاحين';
  bool _pledgeAccepted = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future _submitReport() async {
    if (!_pledgeAccepted) {
      setState(() => _error = 'يجب الموافقة على تعهد الأمانة والمسؤولية قبل رفع التقرير.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final reportDetails = {
        'engine': _engine,
        'gear': _gear,
        'chassis': _chassis,
        'body': _body,
        'airbags': _airbags,
        'ac_and_suspension': _acAndSusp,
        'odometer': _odometerCtrl.text.trim().isEmpty ? 'غير محدد' : '${_odometerCtrl.text.trim()} كم',
        'notes': _notesCtrl.text.trim().isEmpty ? 'لا توجد ملاحظات إضافية' : _notesCtrl.text.trim(),
      };

      await widget.orderRef.update({
        'inspection_status': 'report_ready',
        'inspection_report': 'تقرير الفحص المعتمد جاهز — بانتظار قرار المشتري',
        'inspection_details': reportDetails,
        'inspector_pledge_accepted': true,
        'inspector_pledge_text':
            'تعهد الفاحص بالتزام الأمانة وتحمل كامل المسؤولية النظامية والمالية مع إخلاء مسؤولية معرضي كوسيط تقني، والموافقة على حجز المستحقات 48 ساعة ونافذة الاعتراض 24 ساعة.',
        'inspector_pledge_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: LuxuryColors.success,
          content: Text('تم رفع التقرير الرسمي للمشتري بنجاح وتقييد التعهد.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر رفع التقرير: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 22),
      decoration: BoxDecoration(
        color: LuxuryColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: LuxuryColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.fact_check_outlined, color: LuxuryColors.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تقرير الفحص الرسمي · تطبيق معرضي', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                      Text('${widget.orderCode} · ${widget.carTitle}', style: const TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: LuxuryColors.danger, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            _drop('حالة المحرك (المكينة)', _engine, ['سليم 100%', 'يوجد تهريب / ملاحظات بسيطة', 'عطل أو توضيب'], (v) => setState(() => _engine = v)),
            const SizedBox(height: 10),
            _drop('حالة القير (ناقل الحركة)', _gear, ['سليم 100%', 'ملاحظات بسيطة في التبديل', 'عطل أو توضيب'], (v) => setState(() => _gear = v)),
            const SizedBox(height: 10),
            _drop('حالة الشاصي (الهيكل)', _chassis, ['سليم وكالة', 'تعديل بسيط', 'ضربة شاصي / لحام'], (v) => setState(() => _chassis = v)),
            const SizedBox(height: 10),
            _drop('حالة البودي والرش', _body, ['بودي وكالة بالكامل', 'رش تجميلي نظيف', 'سمكرة وصبغ متعدد'], (v) => setState(() => _body = v)),
            const SizedBox(height: 10),
            _drop('الإيرباقات والأنظمة الإلكترونية', _airbags, ['سليمة (لم تخرج)', 'تنبيهات كمبيوتر بسيطة', 'إيرباق خارج / عطل حساس'], (v) => setState(() => _airbags = v)),
            const SizedBox(height: 10),
            _drop('المكيف والعضلات السفلية', _acAndSusp, ['ممتازة', 'تحتاج صيانة استهلاكية', 'تحتاج إصلاح كبير'], (v) => setState(() => _acAndSusp = v)),
            const SizedBox(height: 10),
            TextField(controller: _odometerCtrl, keyboardType: TextInputType.number, decoration: luxuryInput('قراءة العداد الفعلية (كم)', icon: Icons.speed)),
            const SizedBox(height: 10),
            TextField(controller: _notesCtrl, maxLines: 2, decoration: luxuryInput('ملاحظات الفاحص التفصيلية (تظهر للمشتري)')),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: _pledgeAccepted ? LuxuryColors.goldSoft : const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _pledgeAccepted ? LuxuryColors.gold : LuxuryColors.danger.withValues(alpha: 0.4)),
              ),
              child: CheckboxListTile(
                value: _pledgeAccepted,
                activeColor: LuxuryColors.navy,
                checkColor: LuxuryColors.gold,
                title: const Text('تعهد الأمانة والمسؤولية القانونية (إلزامي)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                subtitle: const Text(
                  'أتعهد أمام الله ثم أمام منصة «معرضي» بالتزام الأمانة والدقة التامة في هذا التقرير، وأقرّ بأن «معرضي» وسيط تقني فقط وأتحمل كامل المسؤولية النظامية والمالية عن أي خطأ أو إخفاء عيب جوهري. كما أوافق على نافذة اعتراض المشتري (24 ساعة أو 50 كم بعد الاستلام) وحجز مستحقات الفحص لمدة 48 ساعة لحماية الحقوق.',
                  style: TextStyle(fontSize: 11.5, color: LuxuryColors.textPrimary, height: 1.45),
                ),
                onChanged: (v) => setState(() => _pledgeAccepted = v ?? false),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LuxuryColors.navy,
                  foregroundColor: LuxuryColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _submitReport,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(
                  _saving ? 'جاري رفع التقرير...' : 'رفع التقرير الرسمي للمشتري',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop(String label, String val, List items, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      decoration: luxuryInput(label),
      items: items.map((e) => DropdownMenuItem<String>(value: e.toString(), child: Text(e.toString()))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}
