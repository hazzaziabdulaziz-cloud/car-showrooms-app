import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/analytics_and_accounting_service.dart';
import '../../core/input_sanitizer.dart';
import '../../core/luxury_theme.dart';
import '../../core/pricing_rules.dart';

class OrderTrackingSheet extends StatefulWidget {
  final String? initialOrderCode;
  final String? initialPhoneLast4;

  const OrderTrackingSheet({
    super.key,
    this.initialOrderCode,
    this.initialPhoneLast4,
  });

  static Future show(
    BuildContext context, {
    String? initialOrderCode,
    String? initialPhoneLast4,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderTrackingSheet(
        initialOrderCode: initialOrderCode,
        initialPhoneLast4: initialPhoneLast4,
      ),
    );
  }

  @override
  State<OrderTrackingSheet> createState() => _OrderTrackingSheetState();
}

class _OrderTrackingSheetState extends State<OrderTrackingSheet> {
  final _codeCtrl = TextEditingController();
  final _phoneLast4Ctrl = TextEditingController();
  String? _selectedPath;
  bool _saving = false;
  bool _demoShowAllPaths = kDebugMode;
  String? _selectedDeliveryCity;
  final _pathCouponCtrl = TextEditingController();
  double _pathDiscount = 0;
  String? _pathAppliedCoupon;
  String? _pathCouponMsg;
  bool _pathCouponValid = false;
  bool _checkingPathCoupon = false;

  Future<void> _applyPathCoupon(int subtotal, String scope) async {
    final code = _pathCouponCtrl.text.trim();
    if (code.isEmpty || subtotal <= 0) return;
    setState(() { _checkingPathCoupon = true; _pathCouponMsg = null; });
    try {
      final res = await AnalyticsAndAccountingService.validateDiscount(
        code: code,
        subtotal: subtotal.toDouble(),
        scope: scope,
      );
      if (!mounted) return;
      final ok = res['valid'] == true;
      setState(() {
        _pathCouponValid = ok;
        _pathCouponMsg = (res['message'] ?? '').toString();
        _pathDiscount = ok ? (res['discountAmount'] as num).toDouble() : 0;
        _pathAppliedCoupon = ok ? (res['code'] ?? code.toUpperCase()).toString() : null;
      });
    } catch (_) {
      if (mounted) setState(() { _pathCouponValid = false; _pathDiscount = 0; _pathCouponMsg = 'تعذر التحقق من الكود حالياً.'; });
    } finally {
      if (mounted) setState(() => _checkingPathCoupon = false);
    }
  }

  Future<void> _openShowroomWhatsApp(String showroomId, String orderCode, String carTitle) async {
    String phone = '';
    if (showroomId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('showrooms').doc(showroomId).get();
        phone = (doc.data()?['contact_phone'] ?? '').toString();
      } catch (_) {}
    }
    final digits = InputSanitizer.cleanSaudiPhone(phone);
    final intl = digits.startsWith('05') ? '966${digits.substring(1)}' : digits;
    final text = Uri.encodeComponent('السلام عليكم، بخصوص الحجز رقم $orderCode للسيارة $carTitle عبر تطبيق معرضي.');
    final uri = Uri.parse(intl.isNotEmpty ? 'https://wa.me/$intl?text=$text' : 'https://wa.me/?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static const _deliveryCities = [
    'الرياض', 'الدمام', 'الخبر', 'الظهران', 'الأحساء', 'الجبيل', 'حفر الباطن',
    'جدة', 'مكة المكرمة', 'الطائف', 'المدينة المنورة', 'ينبع',
    'بريدة (القصيم)', 'أبها (عسير)', 'خميس مشيط', 'تبوك', 'حائل',
    'جازان', 'نجران', 'الباحة', 'سكاكا (الجوف)', 'عرعر',
  ];

  static const _postConfirmPaths = [
    {
      'id': 'inspection_and_shipping',
      'title': 'الباقة المتكاملة عن بُعد (فحص شامل + شحن)',
      'subtitle': 'فاحص مستقل يصدر تقريراً محايداً أولاً، ثم شحن بسطحة معتمدة لمنطقتك',
      'needs_inspection': true,
      'needs_shipping': true,
      'fee': 900,
      'badge': '+900 ر.س',
      'icon': Icons.verified_user_outlined,
    },
    {
      'id': 'inspection_only',
      'title': 'فحص فني شامل فقط',
      'subtitle': 'تقرير معتمد (بودي، مكينة، قير، شاصي، OBD) يصلك قبل إتمام البيع',
      'needs_inspection': true,
      'needs_shipping': false,
      'fee': 250,
      'badge': '+250 ر.س',
      'icon': Icons.fact_check_outlined,
    },
    {
      'id': 'shipping_only',
      'title': 'شحن بسطحة معتمدة فقط',
      'subtitle': 'نقل السيارة مباشرة من صالة المعرض إلى مدينتك',
      'needs_inspection': false,
      'needs_shipping': true,
      'fee': 650,
      'badge': '+650 ر.س تقديري',
      'icon': Icons.local_shipping_outlined,
    },
    {
      'id': 'direct_pickup',
      'title': 'المعاينة والاستلام المباشر من صالة المعرض',
      'subtitle': 'الحضور للمعرض وإتمام المبايعة باستخدام كود التسليم السري بدون خدمات إضافية',
      'needs_inspection': false,
      'needs_shipping': false,
      'fee': 0,
      'badge': 'بدون رسوم إضافية',
      'icon': Icons.storefront_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialOrderCode != null) _codeCtrl.text = widget.initialOrderCode!;
    if (widget.initialPhoneLast4 != null) _phoneLast4Ctrl.text = widget.initialPhoneLast4!;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneLast4Ctrl.dispose();
    _pathCouponCtrl.dispose();
    super.dispose();
  }

  Future _confirmPath(DocumentReference ref, Map path, int dynamicShippingFee, Map<String, dynamic> orderData) async {
    setState(() => _saving = true);
    try {
      final needsInsp = path['needs_inspection'] == true;
      final needsShip = path['needs_shipping'] == true;
      final rawExtraFee = (needsInsp ? PricingRules.inspectionTotal : 0) + (needsShip ? dynamicShippingFee : 0);
      final extraFee = (rawExtraFee - _pathDiscount).clamp(0, rawExtraFee.toDouble()).round();

      await ref.update({
        'post_confirm_path': path['id'],
        'post_confirm_label': path['title'],
        'post_confirm_extra_fee': extraFee,
        'needs_inspection': needsInsp,
        'needs_shipping': needsShip,
        'inspection_status': needsInsp ? 'pending_inspector' : 'none',
        'shipping_status': needsShip ? 'pending_tow' : 'none',
        'inspector_share': needsInsp ? PricingRules.inspectorShare : 0,
        'platform_inspection_share': needsInsp ? PricingRules.platformInspectionShare : 0,
        'buyer_city': _selectedDeliveryCity ?? 'الرياض',
        'shipping_fee': needsShip ? dynamicShippingFee : 0,
        'tow_driver_share': needsShip ? PricingRules.driverTowShare(dynamicShippingFee) : 0,
        'platform_tow_share': needsShip ? PricingRules.platformTowShare(dynamicShippingFee) : 0,
        'status': 'path_selected',
      });

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final buyerName = (orderData['buyer_name'] ?? 'عميل').toString();
      if (needsInsp) {
        await AnalyticsAndAccountingService.trackEvent(AnalyticsAndAccountingService.evBookInspection);
        try {
          await AnalyticsAndAccountingService.issueInvoiceAndRecordLedger(
            orderId: ref.id,
            customerName: buyerName,
            customerUid: uid,
            serviceType: 'inspection',
            subtotal: PricingRules.inspectionTotal.toDouble(),
            discountAmount: (!needsShip ? _pathDiscount : 0),
            discountCode: (!needsShip ? _pathAppliedCoupon : null),
            notes: 'فحص فني شامل - ${orderData['order_code'] ?? ''}',
          );
        } catch (_) {}
      }
      if (needsShip) {
        await AnalyticsAndAccountingService.trackEvent(AnalyticsAndAccountingService.evBookFlatbed);
        try {
          await AnalyticsAndAccountingService.issueInvoiceAndRecordLedger(
            orderId: ref.id,
            customerName: buyerName,
            customerUid: uid,
            serviceType: 'flatbed',
            subtotal: dynamicShippingFee.toDouble(),
            discountAmount: (needsShip ? _pathDiscount : 0),
            discountCode: (needsShip ? _pathAppliedCoupon : null),
            notes: 'شحن سطحة إلى ${_selectedDeliveryCity ?? 'الرياض'} - ${orderData['order_code'] ?? ''}',
          );
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: LuxuryColors.success,
          content: Text(needsInsp && needsShip
              ? 'تم حجز الفاحص والسطحة بنجاح ✓ وأُرسل تنبيه فوري بكامل التفاصيل.'
              : (needsInsp
                  ? 'تم حجز الفاحص المعتمد بنجاح ✓ وأُرسل له تنبيه فوري.'
                  : (needsShip ? 'تم حجز السطحة بنجاح ✓ وظهرت تفاصيل رحلتك لسائقي السطحات.' : 'تم اعتماد الاستلام المباشر من المعرض ✓'))),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التحديث: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildDynamicPathsSection(DocumentReference orderRef, String regionId, String buyerCity, Map<String, dynamic> orderData) {
    final activeCity = _selectedDeliveryCity ?? (_deliveryCities.contains(buyerCity) ? buyerCity : 'الرياض');
    final dynamicShip = PricingRules.estimateShippingFee(regionId, activeCity);
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('inspectors')
          .where('region_id', isEqualTo: regionId)
          .where('is_verified', isEqualTo: true)
          .snapshots(),
      builder: (context, inspSnap) {
        final hasInspectors = _demoShowAllPaths || (inspSnap.data?.docs ?? const []).isNotEmpty;
        return StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('tow_drivers')
              .where('current_region_id', isEqualTo: regionId)
              .snapshots(),
          builder: (context, towSnap) {
            final hasTow = _demoShowAllPaths || (towSnap.data?.docs ?? const []).isNotEmpty;
            final availablePaths = _postConfirmPaths.where((p) {
              final needI = p['needs_inspection'] == true;
              final needS = p['needs_shipping'] == true;
              if (needI && !hasInspectors) return false;
              if (needS && !hasTow) return false;
              return true;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: activeCity,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'حدد مدينة التسليم (يتحدث سعر الشحن تلقائياً)',
                    prefixIcon: Icon(Icons.location_on_outlined, color: LuxuryColors.gold),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _deliveryCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDeliveryCity = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'تم تأكيد توفر سيارتك — اختر مسار إتمام الصفقة:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LuxuryColors.navy),
                      ),
                    ),
                    if (kDebugMode)
                      TextButton.icon(
                        onPressed: () => setState(() => _demoShowAllPaths = !_demoShowAllPaths),
                        icon: Icon(_demoShowAllPaths ? Icons.visibility : Icons.visibility_off, size: 15, color: LuxuryColors.gold),
                        label: Text(
                          _demoShowAllPaths ? 'وضع التجربة: الكل ظاهر' : 'إظهار الفحص والسطحة',
                          style: const TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ...availablePaths.map((p) {
                  final active = _selectedPath == p['id'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedPath = p['id'] as String),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: active ? LuxuryColors.goldSoft : LuxuryColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? LuxuryColors.gold : LuxuryColors.border,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(p['icon'] as IconData, color: LuxuryColors.navy),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: LuxuryColors.navy)),
                                  const SizedBox(height: 2),
                                  Text(p['subtitle'] as String, style: const TextStyle(fontSize: 11.5, color: LuxuryColors.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p['id'] == 'inspection_and_shipping'
                                  ? '+${PricingRules.inspectionTotal + dynamicShip} ر.س'
                                  : (p['id'] == 'shipping_only' ? '+$dynamicShip ر.س' : p['badge'] as String),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LuxuryColors.navy),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_selectedPath != null && _selectedPath != 'direct_pickup') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pathCouponCtrl,
                          decoration: luxuryInput('كود خصم للفحص أو السطحة (مثال: VIP20)', icon: Icons.local_offer_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: LuxuryColors.navy, side: const BorderSide(color: LuxuryColors.gold)),
                          onPressed: _checkingPathCoupon
                              ? null
                              : () {
                                  final sel = availablePaths.firstWhere((e) => e['id'] == _selectedPath);
                                  final ni = sel['needs_inspection'] == true;
                                  final ns = sel['needs_shipping'] == true;
                                  final sub = (ni ? PricingRules.inspectionTotal : 0) + (ns ? dynamicShip : 0);
                                  final sc = ni && !ns ? 'inspection' : (!ni && ns ? 'flatbed' : 'all');
                                  _applyPathCoupon(sub, sc);
                                },
                          child: Text(_checkingPathCoupon ? '...' : 'تطبيق', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                  if (_pathCouponMsg != null) ...[
                    const SizedBox(height: 4),
                    Text(_pathCouponMsg!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _pathCouponValid ? LuxuryColors.success : LuxuryColors.danger)),
                  ],
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: LuxuryColors.navy,
                      foregroundColor: LuxuryColors.gold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (_selectedPath == null || _saving)
                        ? null
                        : () {
                            final matches = availablePaths.where((e) => e['id'] == _selectedPath).toList();
                            if (matches.isEmpty) {
                              setState(() => _selectedPath = null);
                              return;
                            }
                            _confirmPath(orderRef, matches.first, dynamicShip, orderData);
                          },
                    child: Text(
                      _saving ? 'جاري الاعتماد...' : 'اعتماد المسار المختار والمتابعة',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _trackingStatusText(String status, Map<String, dynamic> data) {
    switch (status) {
      case 'paid_waiting_showroom':
      case 'pending_showroom':
        return 'الحالة: بانتظار تأكيد المعرض (مهلة ساعتين)';
      case 'confirmed':
        return 'الحالة: تم تأكيد التوفر ✓ — اختر مسار الإتمام بالأسفل';
      case 'sold_in_showroom_refunded':
        return 'الحالة: انباعت السيارة في الصالة — تم استرجاع العربون لحسابك 100%';
      case 'cancelled_after_confirm':
      case 'cancelled_financing_rejected':
      case 'cancelled_refunded_100':
        return 'الحالة: تم إلغاء الحجز — استرداد العربون 100% لحسابك';
      case 'pending_admin_forfeit_review':
        return 'الحالة: بانتظار مراجعة الإدارة لتسوية العربون';
      case 'cancelled_forfeited_70_30':
        return 'الحالة: تم إلغاء الحجز بعد التأكيد — العربون غير مسترد (70% معرض / 30% منصة)';
      case 'refunded_failed_inspection':
      case 'cancelled_by_buyer_after_inspection':
      case 'cancelled_by_buyer':
        return 'الحالة: تم إلغاء الطلب ومعالجة الاسترجاع';
      case 'completed':
        return 'الحالة: تم إغلاق الصفقة بنجاح ✓';
      default:
        return 'المسار المختار: ${data['post_confirm_label'] ?? status}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final query = uid != null
        ? FirebaseFirestore.instance.collection('orders').where('buyer_uid', isEqualTo: uid).orderBy('created_at', descending: true).limit(20)
        : FirebaseFirestore.instance.collection('orders').orderBy('created_at', descending: true).limit(20);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 22),
      decoration: BoxDecoration(
        color: LuxuryColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
      ),
      child: SingleChildScrollView(
        child: StreamBuilder(
          stream: query.snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            final codeQ = _codeCtrl.text.trim().toUpperCase();
            final phoneQ = InputSanitizer.normalizeDigits(_phoneLast4Ctrl.text.trim());

            final canShow = codeQ.length >= 4 && phoneQ.length == 4;
            final matching = canShow
                ? docs.where((d) {
                    final m = d.data();
                    final c = (m['order_code'] ?? '').toString().toUpperCase();
                    final p = (m['buyer_phone_last4'] ?? '').toString();
                    return c.contains(codeQ) && p == phoneQ;
                  }).toList()
                : [];
            final latestDoc = matching.isNotEmpty ? matching.first : null;
            final data = latestDoc?.data();
            final status = (data?['status'] ?? '').toString();
            final inspStatus = (data?['inspection_status'] ?? 'none').toString();
            final shipStatus = (data?['shipping_status'] ?? 'none').toString();
            final invoiceIssued = data?['invoice_issued'] == true;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: LuxuryColors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'متابعة حجزي الآمنة',
                  style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'لحماية خصوصيتك وكود التسليم، أدخل رقم الحجز مع آخر 4 أرقام من جوالك.',
                        style: TextStyle(fontSize: 12, color: LuxuryColors.textSecondary),
                      ),
                    ),
                    if (kDebugMode && docs.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          final first = docs.first.data();
                          setState(() {
                            _codeCtrl.text = (first['order_code'] ?? '').toString();
                            _phoneLast4Ctrl.text = (first['buyer_phone_last4'] ?? '').toString();
                          });
                        },
                        icon: const Icon(Icons.flash_on, size: 15, color: LuxuryColors.gold),
                        label: const Text('تعبئة آخر حجز', style: TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 11.5)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _codeCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: luxuryInput('رقم الحجز (MRD-...)', icon: Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneLast4Ctrl,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: luxuryInput('آخر 4 أرقام للجوال').copyWith(counterText: ''),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (!canShow)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: Text('أدخل رقم الحجز وآخر 4 أرقام من جوالك لعرض التفاصيل.', style: TextStyle(color: LuxuryColors.textSecondary, fontSize: 13))),
                  )
                else if (latestDoc == null || data == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: Text('لم يتم العثور على حجز مطابق لهذه البيانات.', style: TextStyle(color: LuxuryColors.danger, fontSize: 13))),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['order_code']} · ${data['car_title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('المعرض: ${data['showroom_name']} · كود التسليم السري: ${data['handover_pin'] ?? '---'}', style: const TextStyle(color: LuxuryColors.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          _trackingStatusText(status, data),
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                        if (inspStatus != 'none')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('حالة الفحص: ${data['inspection_report'] ?? 'بانتظار الفاحص المعتمد'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                        if (shipStatus != 'none')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'حالة السطحة: ${shipStatus == 'pending_tow' ? 'تم الحجز ✓ (بانتظار قبول سائق السطحة)' : (shipStatus == 'in_transit' ? 'السيارة على السطحة في الطريق إليك 🚚' : 'تم التسليم بنجاح ✓')}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (data['inspection_details'] is Map) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: LuxuryColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LuxuryColors.gold),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified, color: LuxuryColors.gold, size: 18),
                              SizedBox(width: 6),
                              Text('تقرير الفحص المعتمد من معرضي', style: TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy, fontSize: 13.5)),
                            ],
                          ),
                          const Divider(height: 16),
                          Text('• المحرك: ${(data['inspection_details'] as Map)['engine'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• القير: ${(data['inspection_details'] as Map)['gear'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• الشاصي: ${(data['inspection_details'] as Map)['chassis'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• البودي والرش: ${(data['inspection_details'] as Map)['body'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• الإيرباقات: ${(data['inspection_details'] as Map)['airbags'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• فحص الكمبيوتر (OBD): ${(data['inspection_details'] as Map)['obd_status'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• المكيف والعضلات: ${(data['inspection_details'] as Map)['ac_and_suspension'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• الكفرات والفرامل: ${(data['inspection_details'] as Map)['tires_brakes'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• الداخلية والمفاتيح: ${(data['inspection_details'] as Map)['interior_keys'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• العداد: ${(data['inspection_details'] as Map)['odometer'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          Text('• تكلفة إصلاح تقديرية: ${(data['inspection_details'] as Map)['estimated_repair_cost'] ?? '0 ر.س'}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          Text('• ملاحظات: ${(data['inspection_details'] as Map)['notes'] ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 6),
                          const Text('موثّق إلكترونياً بتعهد الأمانة وتحمل المسؤولية من الفاحص ✓', style: TextStyle(fontSize: 11.5, color: LuxuryColors.success, fontWeight: FontWeight.w700)),
                          if (data['buyer_inspection_decision'] == null && status != 'completed' && status != 'cancelled_by_buyer_after_inspection') ...[
                            const Divider(height: 18),
                            const Text('قرارك بعد الاطلاع على التقرير:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: LuxuryColors.success),
                                    onPressed: () => latestDoc.reference.update({
                                      'buyer_inspection_decision': 'approved',
                                      'inspection_report': 'وافق المشتري على تقرير الفحص واعتمد المتابعة ✓',
                                    }),
                                    child: const Text('اعتماد والمتابعة ✓', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(foregroundColor: LuxuryColors.danger, side: const BorderSide(color: LuxuryColors.danger)),
                                    onPressed: () => latestDoc.reference.update({
                                      'buyer_inspection_decision': 'cancelled',
                                      'status': 'cancelled_by_buyer_after_inspection',
                                      'inspection_report': 'ألغى المشتري الطلب بعد الاطلاع على التقرير (استرجاع العربون)',
                                    }),
                                    child: const Text('إلغاء الطلب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (invoiceIssued) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: LuxuryColors.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: LuxuryColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('فاتورة المبايعة ونقل الملكية (تم / أبشر) جاهزة ✓', style: TextStyle(color: LuxuryColors.success, fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 4),
                          Text('المبلغ المتبقي بعد خصم العربون: ${data['remaining_amount'] ?? '---'} ر.س', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('الحساب البنكي الرسمي للمعرض: ${data['showroom_bank'] ?? 'المسجل بالتطبيق'} · ${data['showroom_iban'] ?? '---'}', style: const TextStyle(fontSize: 12, color: LuxuryColors.navy)),
                        ],
                      ),
                    ),
                  ],
                  if (status == 'confirmed' || status == 'path_selected' || status == 'completed') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LuxuryColors.success,
                          side: const BorderSide(color: LuxuryColors.success),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _openShowroomWhatsApp(
                          (data['showroom_id'] ?? '').toString(),
                          (data['order_code'] ?? '').toString(),
                          (data['car_title'] ?? '').toString(),
                        ),
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('تواصل واتساب مباشر مع المعرض (مفتوح بعد التأكيد ✓)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ),
                    ),
                  ],
                  if (status == 'confirmed')
                    _buildDynamicPathsSection(
                      latestDoc.reference,
                      (data['region_id'] ?? 'riyadh').toString(),
                      (data['buyer_city'] ?? 'الرياض').toString(),
                      data,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
