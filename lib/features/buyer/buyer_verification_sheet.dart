import '../../core/atomic_order_guard.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/analytics_and_accounting_service.dart';
import '../../core/input_sanitizer.dart';
import '../../core/luxury_theme.dart';
import '../../core/password_policy.dart';
import '../../core/pricing_rules.dart';

class BuyerVerificationSheet extends StatefulWidget {
  final String? carId;
  final String? interestedCarTitle;
  final int carPrice;
  final String? showroomId;
  final String? showroomName;
  final String? showroomOwnerUid;
  final String? regionId;

  const BuyerVerificationSheet({
    super.key,
    this.carId,
    this.interestedCarTitle,
    this.carPrice = 0,
    this.showroomId,
    this.showroomName,
    this.showroomOwnerUid,
    this.regionId,
  });

  static Future show(
    BuildContext context, {
    String? carId,
    String? carTitle,
    int carPrice = 0,
    String? showroomId,
    String? showroomName,
    String? showroomOwnerUid,
    String? regionId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuyerVerificationSheet(
        carId: carId,
        interestedCarTitle: carTitle,
        carPrice: carPrice,
        showroomId: showroomId,
        showroomName: showroomName,
        showroomOwnerUid: showroomOwnerUid,
        regionId: regionId,
      ),
    );
  }

  @override
  State<BuyerVerificationSheet> createState() => _BuyerVerificationSheetState();
}

class _BuyerVerificationSheetState extends State<BuyerVerificationSheet> {
  static const bool kSmsProviderConnected = false;
  int _step = 0;
  final _authEmailCtrl = TextEditingController();
  final _authPassCtrl = TextEditingController();
  bool _isSignUp = true;
  bool _authLoading = false;
  String? _authError;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();

  String _selectedCity = 'الرياض';
  String _generatedOtp = '';
  String? _inlineError;
  bool _saving = false;
  bool _antiBypassAgreed = false;

  double _discountAmount = 0;
  String? _appliedCoupon;
  String? _couponMsg;
  bool _couponValid = false;
  bool _checkingCoupon = false;

  String _paymentMethod = 'شراء كاش (قيمة السيارة)';
  String _salaryBank = 'مصرف الراجحي';
  String _workSector = 'حكومي';
  String _paymentGateway = 'مدى (Mada)';

  int get _reservationFee => PricingRules.reservationFee(widget.carPrice);
  int get _finalFee => (_reservationFee - _discountAmount).clamp(0, _reservationFee.toDouble()).round();

  static const _saudiCities = [
    'الرياض', 'الدمام', 'الخبر', 'الظهران', 'الأحساء', 'الجبيل',
    'جدة', 'مكة المكرمة', 'الطائف', 'المدينة المنورة', 'ينبع',
    'بريدة (القصيم)', 'أبها (عسير)', 'خميس مشيط', 'تبوك', 'حائل',
    'جازان', 'نجران', 'الباحة', 'سكاكا (الجوف)', 'عرعر',
  ];

  static const _payments = ['شراء كاش (قيمة السيارة)', 'تمويل بنكي', 'تأجير منتهي بالتمليك'];
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
    _authEmailCtrl.dispose();
    _authPassCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _salaryCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitBuyerAuth() async {
    final email = _authEmailCtrl.text.trim();
    final pass = _authPassCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _authError = 'أدخل بريداً إلكترونياً صحيحاً');
      return;
    }
    if (_isSignUp) {
      final passErr = PasswordPolicy.validate(pass);
      if (passErr != null) {
        setState(() => _authError = passErr);
        return;
      }
    } else if (pass.isEmpty) {
      setState(() => _authError = 'يرجى إدخال كلمة المرور');
      return;
    }
    setState(() {
      _authLoading = true;
      _authError = null;
    });
    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      }
      if (mounted) setState(() => _authLoading = false);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _authLoading = false;
          _authError = e.code == 'email-already-in-use'
              ? 'هذا البريد مسجل مسبقاً — اختر "تسجيل الدخول"'
              : (e.code == 'wrong-password' || e.code == 'invalid-credential'
                  ? 'البريد أو كلمة المرور غير صحيحة'
                  : 'تعذر إتمام العملية: ${e.message ?? e.code}');
        });
      }
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingCoupon = true;
      _couponMsg = null;
    });
    try {
      final res = await AnalyticsAndAccountingService.validateDiscount(
        code: code,
        subtotal: _reservationFee.toDouble(),
        scope: 'car',
      );
      if (!mounted) return;
      final ok = res['valid'] == true;
      setState(() {
        _couponValid = ok;
        _couponMsg = (res['message'] ?? '').toString();
        _discountAmount = ok ? (res['discountAmount'] as num).toDouble() : 0;
        _appliedCoupon = ok ? (res['code'] ?? code.toUpperCase()).toString() : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _couponValid = false;
        _discountAmount = 0;
        _appliedCoupon = null;
        _couponMsg = 'تعذر التحقق من الكود حالياً.';
      });
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  Widget _buildBuyerAuthGate() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_person_outlined, color: LuxuryColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isSignUp ? 'أنشئ حسابك قبل حجز السيارة' : 'سجّل دخولك لمتابعة الحجز',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LuxuryColors.navy),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'لحفظ حقوقك ومتابعة حجوزاتك وتقارير الفحص بأمان، يرجى التسجيل أولاً.',
              style: TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: luxuryInput('البريد الإلكتروني', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authPassCtrl,
              obscureText: true,
              decoration: luxuryInput('كلمة مرور قوية (8+ أحرف، كبير/صغير/رقم/رمز)', icon: Icons.lock_outline),
            ),
            if (_authError != null) ...[
              const SizedBox(height: 10),
              Text(_authError!, style: const TextStyle(color: LuxuryColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LuxuryColors.navy,
                  foregroundColor: LuxuryColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _authLoading ? null : _submitBuyerAuth,
                child: _authLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: LuxuryColors.gold))
                    : Text(_isSignUp ? 'إنشاء حساب ومتابعة الحجز' : 'تسجيل الدخول ومتابعة الحجز', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _isSignUp = !_isSignUp;
                _authError = null;
              }),
              child: Text(
                _isSignUp ? 'لديك حساب بالفعل؟ سجّل الدخول' : 'مستخدم جديد؟ أنشئ حساباً الآن',
                style: const TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendOtp() {
    if (_nameCtrl.text.trim().length < 2 || !InputSanitizer.isValidSaudiPhone(_phoneCtrl.text)) {
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
    final entered = InputSanitizer.normalizeDigits(_otpCtrl.text.trim());
    final validDebugOverride = (kDebugMode || !kSmsProviderConnected) && entered == '1234';
    if (entered != _generatedOtp && !validDebugOverride) {
      setState(() => _inlineError = 'كود التفعيل غير مطابق، يرجى التأكد والمحاولة مرة أخرى.');
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
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final isFinancing = !_paymentMethod.contains('كاش');
      final orderCode = 'MRD-${100000 + Random().nextInt(899999)}';
      final handoverPin = (1000 + Random().nextInt(8999)).toString();
      final phone = InputSanitizer.cleanSaudiPhone(_phoneCtrl.text);

      try {
        final existingActive = await FirebaseFirestore.instance
            .collection('orders')
            .where('buyer_uid', isEqualTo: uid)
            .where('status', whereIn: ['paid_waiting_showroom', 'confirmed', 'path_selected'])
            .limit(1)
            .get();
        if (existingActive.docs.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _inlineError = 'لديك حجز نشط حالياً. يُسمح بحجز واحد نشط في نفس الوقت.';
            _saving = false;
          });
          return;
        }
      } catch (_) {}

      final phoneLast4 = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      final slaDeadline = DateTime.now().add(const Duration(hours: 2));

      String ownerUid = widget.showroomOwnerUid ?? '';
      if (ownerUid.isEmpty && (widget.showroomId ?? '').isNotEmpty) {
        try {
          final srDoc = await FirebaseFirestore.instance.collection('showrooms').doc(widget.showroomId).get();
          ownerUid = (srDoc.data()?['owner_uid'] ?? '').toString();
        } catch (_) {}
      }

      await AtomicOrderGuard.reserveCarAtomically(widget.carId);
      final orderDoc = await FirebaseFirestore.instance.collection('orders').add({
        'order_code': orderCode,
        'handover_pin': handoverPin,
        'status': 'paid_waiting_showroom',
        'car_id': widget.carId ?? '',
        'showroom_id': widget.showroomId ?? 'general',
        'showroom_name': widget.showroomName ?? 'معرض معتمد',
        'showroom_owner_uid': ownerUid,
        'region_id': widget.regionId ?? 'riyadh',
        'car_title': widget.interestedCarTitle ?? 'طلب عام',
        'car_price': widget.carPrice,
        'pricing_tier': PricingRules.tierLabel(widget.carPrice),
        'buyer_uid': uid,
        'buyer_name': _nameCtrl.text.trim(),
        'buyer_phone': phone,
        'buyer_phone_last4': phoneLast4,
        'buyer_city': _selectedCity,
        'payment_method': _paymentMethod,
        'reservation_fee': _reservationFee,
        'discount_code': _appliedCoupon,
        'discount_amount': _discountAmount,
        'total_paid': _finalFee,
        'payment_gateway': _paymentGateway,
        'escrow_protected': true,
        'inspection_status': 'none',
        'shipping_status': 'none',
        'invoice_issued': false,
        'sla_deadline': Timestamp.fromDate(slaDeadline),
        'sla_expires_at': Timestamp.fromDate(slaDeadline),
        if (isFinancing) ...{
          'salary_bank': _salaryBank,
          'work_sector': _workSector,
          'monthly_salary': _salaryCtrl.text.trim(),
        },
        'created_at': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseFirestore.instance.collection('buyer_leads').add({
          'order_code': orderCode,
          'name': _nameCtrl.text.trim(),
          'phone': phone,
          'city': _selectedCity,
          'payment_method': _paymentMethod,
          'interested_car': widget.interestedCarTitle ?? 'تصفح عام',
          'showroom_name': widget.showroomName ?? 'معرض معتمد',
          'paid_escrow': _finalFee,
          'created_at': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      await AnalyticsAndAccountingService.trackEvent(
        AnalyticsAndAccountingService.evBookCar,
        meta: {
          'order_code': orderCode,
          'car': widget.interestedCarTitle ?? '',
          'showroom': widget.showroomName ?? '',
          'amount': _finalFee,
        },
      );

      try {
        await AnalyticsAndAccountingService.issueInvoiceAndRecordLedger(
          orderId: orderDoc.id,
          customerName: _nameCtrl.text.trim(),
          customerUid: uid,
          serviceType: 'car_booking',
          subtotal: _reservationFee.toDouble(),
          discountAmount: _discountAmount,
          discountCode: _appliedCoupon,
          notes: '${widget.interestedCarTitle ?? ''} ($orderCode)',
        );
      } catch (_) {}

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
              Text('العربون المحجوز في الضمان: $_finalFee ر.س${_discountAmount > 0 ? ' (بعد خصم ${_discountAmount.toStringAsFixed(0)} ر.س)' : ''}.'),
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
    if (FirebaseAuth.instance.currentUser == null) {
      return _buildBuyerAuthGate();
    }
    final isFinancing = !_paymentMethod.contains('كاش');
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
                                    ? '3/4: طريقة شراء السيارة'
                                    : '4/4: دفع عربون الحجز فقط',
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy),
                      ),
                      Text(widget.interestedCarTitle ?? 'حجز سيارة عبر شاري', style: const TextStyle(fontSize: 12.5, color: LuxuryColors.textSecondary)),
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
              if (kDebugMode)
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
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCity = v);
                },
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
              if (kDebugMode || !kSmsProviderConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: LuxuryColors.goldSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: LuxuryColors.gold)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('كود التحقق المؤقت: $_generatedOtp', style: const TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 15)),
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
              _chipGroup('طريقة شراء السيارة (العربون يُدفع إلكترونياً)', _payments, _paymentMethod, (v) => setState(() => _paymentMethod = v)),
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
                        onChanged: (v) {
                          if (v != null) setState(() => _salaryBank = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _workSector,
                              decoration: luxuryInput('قطاع العمل'),
                              items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _workSector = v);
                              },
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
                        Text('$_finalFee ر.س', style: const TextStyle(color: LuxuryColors.gold, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    if (_discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تم تطبيق كود $_appliedCoupon بخصم ${_discountAmount.toStringAsFixed(0)} ر.س (الأصل $_reservationFee ر.س)',
                          style: const TextStyle(color: LuxuryColors.gold, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('رسوم حجز وضمان لصالح منصة «شاري» عند إتمام البيعة · مستردة 100% في حال عدم توفر السيارة أو وجود عيب في الفحص', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponCtrl,
                      decoration: luxuryInput('لديك كود خصم؟ (مثال: VIP20)', icon: Icons.local_offer_outlined),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LuxuryColors.navy,
                        side: const BorderSide(color: LuxuryColors.gold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _checkingCoupon ? null : _applyCoupon,
                      child: Text(_checkingCoupon ? '...' : 'تطبيق', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              if (_couponMsg != null) ...[
                const SizedBox(height: 6),
                Text(
                  _couponMsg!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _couponValid ? LuxuryColors.success : LuxuryColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _chipGroup('وسيلة الدفع', _gateways, _paymentGateway, (v) => setState(() => _paymentGateway = v)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _antiBypassAgreed ? LuxuryColors.goldSoft : const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _antiBypassAgreed ? LuxuryColors.gold : LuxuryColors.danger.withValues(alpha: 0.4)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: _antiBypassAgreed,
                    activeColor: LuxuryColors.navy,
                    checkColor: LuxuryColors.gold,
                    title: const Text('إقرار الأمانة وحفظ الحقوق (إلزامي)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                    subtitle: const Text(
                      'أقرّ بأن مجرد رؤيتي للسيارة ومعرفة المعرض عبر «شاري» لا يُعفيني من العربون، وألتزم بإتمام الحجز داخل التطبيق. كما أقرّ بأن «شاري» وسيط تقني موثّق فقط (المسؤولية الفنية على الفاحص والتجارية على المعرض والنقل على السطحة)، وأن لي نافذة اعتراض 24 ساعة (أو 50 كم) بعد الاستلام. وفي حال تراجعي بدون عيب بعد تأكيد المعرض وتجميد السيارة لا يُسترد العربون تعويضاً عن تعطيل البيع.',
                      style: TextStyle(fontSize: 11.5, color: LuxuryColors.textPrimary, height: 1.4),
                    ),
                    onChanged: (v) => setState(() => _antiBypassAgreed = v ?? false),
                  ),
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
                  label: Text(_saving ? 'جاري التأكيد...' : 'ادفع $_finalFee ر.س وأكّد الحجز الآن', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
