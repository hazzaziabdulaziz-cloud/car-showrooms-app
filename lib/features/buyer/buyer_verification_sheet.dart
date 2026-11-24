import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/luxury_theme.dart';
import '../../core/pricing_rules.dart';

class BuyerVerificationSheet extends StatefulWidget {
  final String? interestedCarTitle;
  final int carPrice;
  final String? showroomId;
  final String? showroomName;
  final String? regionId;

  const BuyerVerificationSheet({
    super.key,
    this.interestedCarTitle,
    this.carPrice = 0,
    this.showroomId,
    this.showroomName,
    this.regionId,
  });

  static Future show(
    BuildContext context, {
    String? carTitle,
    int carPrice = 0,
    String? showroomId,
    String? showroomName,
    String? regionId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuyerVerificationSheet(
        interestedCarTitle: carTitle,
        carPrice: carPrice,
        showroomId: showroomId,
        showroomName: showroomName,
        regionId: regionId,
      ),
    );
  }

  @override
  State<BuyerVerificationSheet> createState() => _BuyerVerificationSheetState();
}

class _BuyerVerificationSheetState extends State<BuyerVerificationSheet> {
  // 0: بيانات المشتري | 1: كود OTP | 2: طريقة الشراء (كاش/تمويل) | 3: دفع عربون الحجز فقط
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  String _selectedCity = 'الرياض';
  String _generatedOtp = '';
  String? _inlineError;
  bool _saving = false;
  bool _antiBypassAgreed = false;

  String _paymentMethod = 'كاش';
  String _salaryBank = 'مصرف الراجحي';
  String _workSector = 'حكومي';
  String _paymentGateway = 'مدى (Mada)';

  int get _reservationFee => PricingRules.reservationFee(widget.carPrice);

  static const _saudiCities = [
    'الرياض', 'الدمام', 'الخبر', 'الظهران', 'الأحساء', 'الجبيل',
    'جدة', 'مكة المكرمة', 'الطائف', 'المدينة المنورة', 'ينبع',
    'بريدة (القصيم)', 'أبها (عسير)', 'خميس مشيط', 'تبوك', 'حائل',
    'جازان', 'نجران', 'الباحة', 'سكاكا (الجوف)', 'عرعر',
  ];

  static const _payments = ['كاش', 'تمويل بنكي', 'تأجير منتهي بالتمليك'];
  static const _banks = [
    'مصرف الراجحي', 'البنك الأهلي السعودي (SNB)', 'بنك الرياض',
    'مصرف الإنماء', 'بنك البلاد', 'البنك السعودي الأول (SAB)',
    'البنك السعودي الفرنسي (BSF)', 'البنك العربي الوطني (ANB)',
    'بنك الجزيرة', 'البنك السعودي للاستثمار (SAIB)', 'بنك الخليج الدولي (ميم)',
    'بنك STC (stc bank)', 'بنك D360', 'بنك فيجن (Vision Bank)', 'بنك آخر',
  ];
  static const _sectors = ['حكومي', 'شبه حكومي', 'قطاع خاص', 'أعمال حرة'];
  static const _gateways = ['مدى (Mada)', 'Apple Pay', 'بطاقة ائتمانية'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (_nameCtrl.text.trim().length < 2 || _phoneCtrl.text.trim().length < 9) {
      setState(() => _inlineError = 'يرجى إدخال الاسم ورقم الجوال بشكل صحيح (05xxxxxxxx).');
      return;
    }
    _generatedOtp = (1000 + Random().nextInt(9000)).toString();
    setState(() {
      _inlineError = null;
      _step = 1;
    });
  }

  void _verifyOtp() {
    final entered = _otpCtrl.text.trim();
    if (entered != _generatedOtp && entered != '1234') {
      setState(() => _inlineError = 'الكود غير مطابق. أدخل الكود الظاهر في الصندوق الذهبي أعلاه.');
      return;
    }
    setState(() {
      _inlineError = null;
      _step = 2;
    });
  }

  Future _confirmDepositAndCreateOrder() async {
    if (!_antiBypassAgreed) {
      setState(() => _inlineError = 'يرجى الموافقة على إقرار الأمانة وسياسة العربون قبل إتمام الدفع.');
      return;
    }
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    try {
      final isFinancing = _paymentMethod != 'كاش';
      final orderCode = 'MRD-${100000 + Random().nextInt(899999)}';
      final handoverPin = (1000 + Random().nextInt(8999)).toString();
      final phone = _phoneCtrl.text.trim();
      final existingActive = await FirebaseFirestore.instance
          .collection('orders')
          .where('buyer_phone', isEqualTo: phone)
          .where('status', whereIn: ['paid_waiting_showroom', 'confirmed', 'path_selected'])
          .limit(1)
          .get();
      if (existingActive.docs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _inlineError = 'لديك حجز نشط حالياً بهذا الرقم. لحماية المعارض من تعطيل البيع، يُسمح بحجز واحد نشط في نفس الوقت.';
          _saving = false;
        });
        return;
      }
      final phoneLast4 = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      final slaDeadline = DateTime.now().add(const Duration(hours: 2));

      await FirebaseFirestore.instance.collection('orders').add({
        'order_code': orderCode,
        'handover_pin': handoverPin,
        'status': 'paid_waiting_showroom',
        'showroom_id': widget.showroomId ?? 'general',
        'showroom_name': widget.showroomName ?? 'معرض معتمد',
        'region_id': widget.regionId ?? 'riyadh',
        'car_title': widget.interestedCarTitle ?? 'طلب عام',
        'car_price': widget.carPrice,
        'pricing_tier': PricingRules.tierLabel(widget.carPrice),
        'buyer_name': _nameCtrl.text.trim(),
        'buyer_phone': phone,
        'buyer_phone_last4': phoneLast4,
        'buyer_city': _selectedCity,
        'payment_method': _paymentMethod,
        'reservation_fee': _reservationFee,
        'total_paid': _reservationFee,
        'payment_gateway': _paymentGateway,
        'escrow_protected': true,
        'inspection_status': 'none',
        'shipping_status': 'none',
        'invoice_issued': false,
        'sla_deadline': Timestamp.fromDate(slaDeadline),
        if (isFinancing) ...{
          'salary_bank': _salaryBank,
          'work_sector': _workSector,
          'monthly_salary': _salaryCtrl.text.trim(),
        },
        'created_at': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('buyer_leads').add({
        'order_code': orderCode,
        'name': _nameCtrl.text.trim(),
        'phone': phone,
        'city': _selectedCity,
        'payment_method': _paymentMethod,
        'interested_car': widget.interestedCarTitle ?? 'تصفح عام',
        'showroom_name': widget.showroomName ?? 'معرض معتمد',
        'paid_escrow': _reservationFee,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.verified, color: LuxuryColors.success),
              SizedBox(width: 8),
              Text('تم حجز السيارة بنجاح', style: TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الحجز المرجعي: $orderCode', style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: LuxuryColors.goldSoft, borderRadius: BorderRadius.circular(8)),
                child: Text('كود التسليم السري: $handoverPin (لا تشاركه إلا عند الاستلام)', style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Text('العربون المحجوز في الضمان: $_reservationFee ر.س (يُخصم من قيمة السيارة).'),
              const SizedBox(height: 8),
              const Text(
                'فور تأكيد المعرض خلال ساعتين، افتح «متابعة حجزي» لاختيار (الفحص الشامل / الشحن / الاستلام المباشر) واستلام فاتورة المبايعة.',
                style: TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary, height: 1.5),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = 'تعذر إتمام الدفع: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFinancing = _paymentMethod != 'كاش';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shield_outlined, color: LuxuryColors.gold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _step == 0
                            ? '1/4: بيانات المشتري'
                            : _step == 1
                                ? '2/4: كود التفعيل (OTP)'
                                : _step == 2
                                    ? '3/4: طريقة الشراء (كاش / تمويل)'
                                    : '4/4: دفع عربون الحجز فقط',
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy),
                      ),
                      Text(widget.interestedCarTitle ?? 'حجز سيارة عبر معرضي', style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_inlineError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(10)),
                child: Text(_inlineError!, style: const TextStyle(color: LuxuryColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            if (_step == 0) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _nameCtrl.text = 'عبدالعزيز (مشتري تجريبي)';
                      _phoneCtrl.text = '0550138323';
                    });
                  },
                  icon: const Icon(Icons.flash_on, size: 16, color: LuxuryColors.gold),
                  label: const Text('تعبئة سريعة للتجربة', style: TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
              TextField(controller: _nameCtrl, decoration: luxuryInput('الاسم الكامل', icon: Icons.person_outline)),
              const SizedBox(height: 12),
              TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: luxuryInput('رقم الجوال (05xxxxxxxx)', icon: Icons.phone_android)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCity,
                decoration: luxuryInput('مدينتك الحالية', icon: Icons.location_city),
                items: _saudiCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { if (v != null) setState(() => _selectedCity = v); },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _sendOtp,
                  child: const Text('إرسال كود التفعيل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else if (_step == 1) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: LuxuryColors.goldSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: LuxuryColors.gold)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('كود التجربة: $_generatedOtp', style: const TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 15)),
                    TextButton(
                      onPressed: () {
                        _otpCtrl.text = _generatedOtp;
                        _verifyOtp();
                      },
                      child: const Text('تعبئة وتأكيد فوري', style: TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: const TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w800),
                decoration: luxuryInput('كود التفعيل (4 أرقام)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: LuxuryColors.gold, foregroundColor: LuxuryColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _verifyOtp,
                  child: const Text('تأكيد الكود والمتابعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ] else if (_step == 2) ...[
              _chipGroup('طريقة الشراء', _payments, _paymentMethod, (v) => setState(() => _paymentMethod = v)),
              if (isFinancing) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: LuxuryColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.5))),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _salaryBank,
                        decoration: luxuryInput('البنك الذي ينزل عليه الراتب', icon: Icons.account_balance_outlined),
                        items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _salaryBank = v); },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _workSector,
                              decoration: luxuryInput('قطاع العمل'),
                              items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) { if (v != null) setState(() => _workSector = v); },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _salaryCtrl, keyboardType: TextInputType.number, decoration: luxuryInput('الراتب (ر.س)'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'ملاحظة: خيارات الفحص الشامل والشحن بالسطحة تُفعّل لك بعد تأكيد المعرض لتوفر السيارة، حتى لا تدفع أي رسوم إضافية قبل التأكد.',
                style: TextStyle(fontSize: 12, color: LuxuryColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => setState(() => _step = 3),
                  child: const Text('المتابعة لدفع عربون الحجز', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('عربون الحجز (${PricingRules.tierLabel(widget.carPrice)})', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('$_reservationFee ر.س', style: const TextStyle(color: LuxuryColors.gold, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('يُخصم بالكامل من قيمة السيارة · 0% عمولة على المشتري', style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _chipGroup('وسيلة الدفع', _gateways, _paymentGateway, (v) => setState(() => _paymentGateway = v)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _antiBypassAgreed ? LuxuryColors.goldSoft : const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _antiBypassAgreed ? LuxuryColors.gold : LuxuryColors.danger.withValues(alpha: 0.4)),
                ),
                child: CheckboxListTile(
                  value: _antiBypassAgreed,
                  activeColor: LuxuryColors.navy,
                  checkColor: LuxuryColors.gold,
                  title: const Text('إقرار الأمانة وعدم الالتفاف (إلزامي)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                  subtitle: const Text(
                    'أقرّ بأن مجرد رؤيتي للسيارة ومعرفة المعرض عبر «معرضي» لا يُعفيني من العربون، وألتزم بإتمام الحجز داخل التطبيق. وفي حال تراجعي بدون عيب بعد التجميد يُصادر العربون (70% للمعرض و30% للمنصة).',
                    style: TextStyle(fontSize: 11.5, color: LuxuryColors.textPrimary, height: 1.4),
                  ),
                  onChanged: (v) => setState(() => _antiBypassAgreed = v ?? false),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: LuxuryColors.gold, foregroundColor: LuxuryColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _saving ? null : _confirmDepositAndCreateOrder,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: Text(_saving ? 'جاري التأكيد...' : 'ادفع $_reservationFee ر.س وأكّد الحجز الآن', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipGroup(String title, List options, String selected, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: LuxuryColors.navy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final s = opt.toString();
            final active = s == selected;
            return ChoiceChip(
              label: Text(s),
              selected: active,
              selectedColor: LuxuryColors.navy,
              backgroundColor: LuxuryColors.background,
              labelStyle: TextStyle(color: active ? LuxuryColors.gold : LuxuryColors.textPrimary, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 12.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: active ? LuxuryColors.gold : LuxuryColors.border)),
              onSelected: (_) => onSelect(s),
            );
          }).toList(),
        ),
      ],
    );
  }
}
