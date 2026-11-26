import '../shared/about_and_contact_screen.dart';
import '../shared/legal_and_privacy_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics_and_accounting_service.dart';
import '../../core/luxury_theme.dart';
import '../../core/pricing_rules.dart';
import '../../data/showroom_repository.dart';
import 'buyer_verification_sheet.dart';
import 'my_orders_screen.dart';

String _formatPrice(num value) {
  final str = value.round().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    final posFromRight = str.length - i;
    buffer.write(str[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

int _estimateMonthly(int price) {
  if (price <= 0) return 0;
  final financed = price * 0.90;
  final totalProfit = financed * 0.049 * 5.0;
  final balloon = price * 0.25;
  final m = ((financed + totalProfit - balloon) / 60).round();
  return m > 0 ? m : 0;
}

dynamic _readField(dynamic item, List<String> keys, {dynamic fallback = ''}) {
  if (item == null) return fallback;
  if (item is Map) {
    for (final k in keys) {
      if (item.containsKey(k) && item[k] != null) return item[k];
    }
    return fallback;
  }
  for (final k in keys) {
    try {
      final val = switch (k) {
        'id' => item.id,
        'owner_uid' || 'ownerUid' => item.ownerUid,
        'showroom_id' || 'showroomId' => item.showroomId,
        'region_id' || 'regionId' => item.regionId,
        'city_hub' || 'cityHub' => item.cityHub,
        'condition' => item.condition,
        'make' => item.make,
        'model' => item.model,
        'year' => item.year,
        'price' => item.price,
        'mileage' => item.mileage,
        'status' => item.status,
        'showroom_name' || 'showroomName' => item.showroomName,
        'body_condition' || 'bodyCondition' => item.bodyCondition,
        'spec_type' || 'specType' => item.specType,
        'image_urls' || 'imageUrls' => item.imageUrls,
        _ => null,
      };
      if (val != null) return val;
    } catch (_) {}
  }
  return fallback;
}

List<String> _readImages(dynamic car) {
  final raw = _readField(car, ['image_urls', 'imageUrls'], fallback: const <String>[]);
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.startsWith('http')).toList();
  }
  return const [];
}

int _readPrice(dynamic car) {
  final raw = _readField(car, ['price'], fallback: 0);
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw.toString()) ?? 0;
}

/// الصفحة الأولى: بوابة مناطق المملكة مع البحث الشامل
class RegionsHomeScreen extends StatefulWidget {
  final ShowroomRepository repository;
  final VoidCallback onOpenPartnerPortal;

  const RegionsHomeScreen({
    super.key,
    required this.repository,
    required this.onOpenPartnerPortal,
  });

  @override
  State<RegionsHomeScreen> createState() => _RegionsHomeScreenState();
}

class _RegionsHomeScreenState extends State<RegionsHomeScreen> {
  final _globalSearchCtrl = TextEditingController();
  String _globalCondition = 'all';
  String _sortBy = 'newest';

  @override
  void dispose() {
    _globalSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LuxuryColors.background,
      child: StreamBuilder<List<ShowroomModel>>(
        stream: widget.repository.watchShowrooms(),
        builder: (context, srSnap) {
          final allShowrooms = srSnap.data ?? const <ShowroomModel>[];
          return StreamBuilder<List<dynamic>>(
            stream: widget.repository.watchCars(),
            builder: (context, carSnap) {
              final allCars = (carSnap.data ?? const <dynamic>[])
                  .where((c) => _readField(c, ['status'], fallback: 'available').toString() != 'sold')
                  .toList();

              final q = _globalSearchCtrl.text.trim().toLowerCase();
              final isSearching = q.isNotEmpty || _globalCondition != 'all' || _sortBy != 'newest';
              final filteredGlobal = allCars.where((c) {
                final okCond = _globalCondition == 'all' || _readField(c, ['condition'], fallback: 'new').toString() == _globalCondition;
                final text = '${_readField(c, ['make'])} ${_readField(c, ['model'])} ${_readField(c, ['year'])} ${_readField(c, ['showroom_name', 'showroomName'])}'.toLowerCase();
                return okCond && (q.isEmpty || text.contains(q));
              }).toList();

              if (_sortBy == 'price_asc') {
                filteredGlobal.sort((a, b) => _readPrice(a).compareTo(_readPrice(b)));
              } else if (_sortBy == 'price_desc') {
                filteredGlobal.sort((a, b) => _readPrice(b).compareTo(_readPrice(a)));
              }

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: LuxuryColors.navy,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
                          boxShadow: [BoxShadow(color: LuxuryColors.navy.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 10))],
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runAlignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 16,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: LuxuryColors.navyLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      'شارع المعارض الرقمي · تجربة زيارة المعارض عن بُعد',
                                      style: TextStyle(color: LuxuryColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'اختر المنطقة التي تريد زيارة معارضها',
                                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'تجوّل بين تجمعات المعارض الموثقة في كل منطقة، عاين السيارات، واحجز سيارتك بعربون محمي عبر «ضمان شاري» مع خيار الفحص والشحن لباب بيتك.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.55),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: LuxuryColors.gold,
                                    foregroundColor: LuxuryColors.navy,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: widget.onOpenPartnerPortal,
                                  icon: const Icon(Icons.storefront, size: 18),
                                  label: const Text('سجّل معرضك أو سطحتك', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: LuxuryColors.gold),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
                                  icon: const Icon(Icons.confirmation_number_outlined, size: 18, color: LuxuryColors.gold),
                                  label: const Text('متابعة حجزي', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // شريط البحث الشامل على مستوى المملكة
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: LuxuryColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LuxuryColors.border),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 340,
                              child: TextField(
                                controller: _globalSearchCtrl,
                                onChanged: (_) => setState(() {}),
                                decoration: luxuryInput('ابحث عن أي سيارة في المملكة (مثلاً: كامري 2026)...', icon: Icons.search),
                              ),
                            ),
                            _filterChip('all', 'الكل'),
                            _filterChip('new', 'جديدة'),
                            _filterChip('used', 'مستعملة'),
                            SizedBox(
                              width: 190,
                              child: DropdownButtonFormField<String>(
                                initialValue: _sortBy,
                                decoration: luxuryInput('الترتيب'),
                                items: const [
                                  DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
                                  DropdownMenuItem(value: 'price_asc', child: Text('السعر: الأقل أولاً')),
                                  DropdownMenuItem(value: 'price_desc', child: Text('السعر: الأعلى أولاً')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _sortBy = v);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSearching) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('نتائج البحث على مستوى المملكة (${filteredGlobal.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                            TextButton(
                              onPressed: () => setState(() {
                                _globalSearchCtrl.clear();
                                _globalCondition = 'all';
                                _sortBy = 'newest';
                              }),
                              child: const Text('مسح الفلتر'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (filteredGlobal.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('لا توجد سيارات مطابقة لهذا البحث حالياً.', style: TextStyle(color: LuxuryColors.textSecondary)),
                          )
                        else
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: filteredGlobal.map((car) => _CarListingCard(car: car)).toList(),
                          ),
                      ],
                      const SizedBox(height: 28),
                      const Text('مناطق المملكة (13 منطقة)', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                      const SizedBox(height: 4),
                      const Text('اضغط على أي منطقة للدخول إلى شارع معارضها واستعراض الصالات والسيارات المتاحة', style: TextStyle(fontSize: 13, color: LuxuryColors.textSecondary)),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final cols = w >= 1000 ? 4 : (w >= 650 ? 2 : 1);
                          const spacing = 14.0;
                          final cardW = (w - spacing * (cols - 1)) / cols;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: kSaudiRegions.map((region) {
                              final srCount = allShowrooms.where((s) => s.regionId == region.id).length;
                              final carCount = allCars.where((c) => _readField(c, ['region_id', 'regionId']).toString() == region.id).length;
                              final isActive = srCount > 0 || carCount > 0;
                              return SizedBox(
                                width: cardW,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => RegionShowroomsStreetScreen(regionId: region.id, repository: widget.repository)),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: LuxuryColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isActive ? LuxuryColors.gold.withValues(alpha: 0.7) : LuxuryColors.border,
                                        width: isActive ? 1.4 : 1,
                                      ),
                                      boxShadow: [BoxShadow(color: LuxuryColors.navy.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(color: isActive ? LuxuryColors.navy : LuxuryColors.background, borderRadius: BorderRadius.circular(10)),
                                              child: Icon(Icons.location_on_outlined, color: isActive ? LuxuryColors.gold : LuxuryColors.textSecondary, size: 20),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(color: isActive ? LuxuryColors.successBg : LuxuryColors.background, borderRadius: BorderRadius.circular(8)),
                                              child: Text(
                                                isActive ? 'معارض نشطة' : 'متاح للتسجيل',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? LuxuryColors.success : LuxuryColors.textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Text(region.nameAr, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                                        const SizedBox(height: 4),
                                        Text(region.hubs.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
                                        const Divider(height: 22),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('$srCount معرض · $carCount سيارة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LuxuryColors.navy)),
                                            const Icon(Icons.arrow_forward_ios, size: 13, color: LuxuryColors.gold),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      // Enterprise Footer
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(20), border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.35))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              runSpacing: 14,
                              spacing: 20,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('شاري', style: TextStyle(color: LuxuryColors.gold, fontSize: 20, fontWeight: FontWeight.w800)),
                                    SizedBox(height: 4),
                                    Text('شارع المعارض الرقمي في المملكة العربية السعودية', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                                  ],
                                ),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: LuxuryColors.gold.withValues(alpha: 0.5))),
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutAndContactScreen(initialSection: 0))),
                                      icon: const Icon(Icons.info_outline, size: 16, color: LuxuryColors.gold),
                                      label: const Text('من نحن', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: LuxuryColors.gold.withValues(alpha: 0.5))),
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutAndContactScreen(initialSection: 1))),
                                      icon: const Icon(Icons.support_agent_outlined, size: 16, color: LuxuryColors.gold),
                                      label: const Text('تواصل معنا', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: LuxuryColors.gold.withValues(alpha: 0.5))),
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalAndPrivacyScreen())),
                                      icon: const Icon(Icons.policy_outlined, size: 16, color: LuxuryColors.gold),
                                      label: const Text('الشروط والخصوصية (PDPL)', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 28),
                            const Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                Text('© 2026 منصة شاري · جميع الحقوق محفوظة', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                Text('البيانات مستضافة داخل المملكة العربية السعودية (me-central2)', style: TextStyle(color: LuxuryColors.gold, fontSize: 11.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _filterChip(String val, String label) {
    final active = _globalCondition == val;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: LuxuryColors.navy,
      labelStyle: TextStyle(color: active ? LuxuryColors.gold : LuxuryColors.navy, fontWeight: FontWeight.w700, fontSize: 12.5),
      onSelected: (_) => setState(() => _globalCondition = val),
    );
  }
}

/// الصفحة الثانية: داخل شارع معارض المنطقة المختارة
class RegionShowroomsStreetScreen extends StatefulWidget {
  final String regionId;
  final ShowroomRepository repository;

  const RegionShowroomsStreetScreen({super.key, required this.regionId, required this.repository});

  @override
  State<RegionShowroomsStreetScreen> createState() => _RegionShowroomsStreetScreenState();
}

class _RegionShowroomsStreetScreenState extends State<RegionShowroomsStreetScreen> {
  String _selectedHub = 'الكل';
  String _condition = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = findRegion(widget.regionId);
    final hubs = ['الكل', ...region.hubs];

    return Scaffold(
      backgroundColor: LuxuryColors.background,
      appBar: AppBar(
        backgroundColor: LuxuryColors.navy,
        foregroundColor: Colors.white,
        title: Text('شارع معارض ${region.nameAr}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: StreamBuilder<List<ShowroomModel>>(
        stream: widget.repository.watchShowrooms(),
        builder: (context, srSnap) {
          final showrooms = (srSnap.data ?? const <ShowroomModel>[]).where((s) {
            return s.regionId == widget.regionId && (_selectedHub == 'الكل' || s.cityHub == _selectedHub);
          }).toList();

          return StreamBuilder<List<dynamic>>(
            stream: widget.repository.watchCars(),
            builder: (context, carSnap) {
              final q = _searchCtrl.text.trim().toLowerCase();
              final allRegionCars = (carSnap.data ?? const <dynamic>[]).where((c) {
                return _readField(c, ['region_id', 'regionId']).toString() == widget.regionId &&
                    _readField(c, ['status'], fallback: 'available').toString() != 'sold';
              }).toList();

              final cars = allRegionCars.where((c) {
                final okHub = _selectedHub == 'الكل' || _readField(c, ['city_hub', 'cityHub']).toString() == _selectedHub;
                final okCond = _condition == 'all' || _readField(c, ['condition'], fallback: 'new').toString() == _condition;
                final text = '${_readField(c, ['make'])} ${_readField(c, ['model'])} ${_readField(c, ['showroom_name', 'showroomName'])}'.toLowerCase();
                return okHub && okCond && (q.isEmpty || text.contains(q));
              }).toList();

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: LuxuryColors.navy,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('شارع معارض ${region.nameAr}', style: const TextStyle(color: LuxuryColors.gold, fontSize: 20, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('معارض وسيارات منطقة ${region.nameAr} الموثقة · ${showrooms.length} معرض · ${cars.length} سيارة متاحة', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.location_city, color: LuxuryColors.gold, size: 32),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: LuxuryColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxuryColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 320,
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (_) => setState(() {}),
                                    decoration: luxuryInput('ابحث عن سيارة أو معرض في ${region.nameAr}...', icon: Icons.search),
                                  ),
                                ),
                                _condChip('all', 'الكل'),
                                _condChip('new', 'جديدة'),
                                _condChip('used', 'مستعملة'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: hubs.map((h) {
                                  final active = _selectedHub == h;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: ChoiceChip(
                                      label: Text(h),
                                      selected: active,
                                      selectedColor: LuxuryColors.navy,
                                      backgroundColor: LuxuryColors.background,
                                      labelStyle: TextStyle(color: active ? LuxuryColors.gold : LuxuryColors.navy, fontWeight: FontWeight.w700, fontSize: 12.5),
                                      onSelected: (_) => setState(() => _selectedHub = h),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('المعارض في ${region.nameAr} (${showrooms.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                      const SizedBox(height: 12),
                      if (showrooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('لا توجد معارض مسجلة في هذا التجمع حالياً.', style: TextStyle(color: LuxuryColors.textSecondary)),
                        )
                      else
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: showrooms.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final sr = showrooms[i];
                              final srCars = allRegionCars.where((c) {
                                final id = _readField(c, ['showroom_id', 'showroomId']).toString();
                                final name = _readField(c, ['showroom_name', 'showroomName']).toString();
                                return (id.isNotEmpty && id == sr.id) || name == sr.commercialName;
                              }).toList();
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  AnalyticsAndAccountingService.trackEvent(AnalyticsAndAccountingService.evBrowseShowroom, meta: {'showroom': sr.commercialName});
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShowroomProfileScreen(showroom: sr, cars: srCars)));
                                },
                                child: Container(
                                  width: 280,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: LuxuryColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: LuxuryColors.border)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.storefront, color: LuxuryColors.navy),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(sr.commercialName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy))),
                                          if (sr.isVerified) const Icon(Icons.verified, color: LuxuryColors.gold, size: 18),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(sr.cityHub, style: const TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${srCars.length} سيارة', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                          const Text('دخول الصالة ←', style: TextStyle(color: LuxuryColors.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 28),
                      Text('السيارات المتاحة في ${region.nameAr} (${cars.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                      const SizedBox(height: 12),
                      if (cars.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا توجد سيارات مطابقة للبحث حالياً.', style: TextStyle(color: LuxuryColors.textSecondary)),
                        )
                      else
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: cars.map((car) => _CarListingCard(car: car)).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _condChip(String val, String label) {
    final active = _condition == val;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: LuxuryColors.navy,
      labelStyle: TextStyle(color: active ? LuxuryColors.gold : LuxuryColors.navy, fontWeight: FontWeight.w700, fontSize: 12.5),
      onSelected: (_) => setState(() => _condition = val),
    );
  }
}

class _CarListingCard extends StatelessWidget {
  final dynamic car;
  const _CarListingCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final make = _readField(car, ['make']).toString();
    final model = _readField(car, ['model']).toString();
    final year = _readField(car, ['year']).toString();
    final price = _readPrice(car);
    final monthly = _estimateMonthly(price);
    final srName = _readField(car, ['showroom_name', 'showroomName'], fallback: 'معرض معتمد').toString();
    final hub = _readField(car, ['city_hub', 'cityHub']).toString();
    final images = _readImages(car);
    final mileage = _readField(car, ['mileage'], fallback: 0);
    final isNew = _readField(car, ['condition'], fallback: 'new') == 'new';

    return SizedBox(
      width: 350,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          AnalyticsAndAccountingService.trackEvent(AnalyticsAndAccountingService.evBrowseCar, meta: {'car': '$make $model $year'});
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarDetailsScreen(car: car)));
        },
        child: Container(
          decoration: BoxDecoration(
            color: LuxuryColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuxuryColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: images.isNotEmpty
                    ? Image.network(
                        images.first,
                        height: 165,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            isNew ? 'جديدة (أصفار)' : 'مستعملة · $mileage كم',
                            style: const TextStyle(color: LuxuryColors.gold, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(year, style: const TextStyle(fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('$make $model', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                    const SizedBox(height: 4),
                    Text('$srName · $hub', style: const TextStyle(fontSize: 12, color: LuxuryColors.textSecondary)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_formatPrice(price)} ر.س', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                            Text('قسط ~ ${_formatPrice(monthly)} ر.س/شهر', style: const TextStyle(fontSize: 11.5, color: LuxuryColors.success, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: LuxuryColors.navy, foregroundColor: LuxuryColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () {
                            AnalyticsAndAccountingService.trackEvent(AnalyticsAndAccountingService.evBrowseCar, meta: {'car': '$make $model $year'});
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarDetailsScreen(car: car)));
                          },
                          child: const Text('معاينة وحجز', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
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
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: LuxuryColors.navy.withValues(alpha: 0.06),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_outlined, size: 42, color: LuxuryColors.navyLight),
          SizedBox(height: 4),
          Text('بانتظار رفع صور المعرض', style: TextStyle(fontSize: 11.5, color: LuxuryColors.textSecondary)),
        ],
      ),
    );
  }
}

/// الصفحة الثالثة: تفاصيل السيارة مع معرض الصور ومشاركة واتساب والحجز
class CarDetailsScreen extends StatelessWidget {
  final dynamic car;
  const CarDetailsScreen({super.key, required this.car});

  Future<void> _shareOnWhatsApp(String title, int price, String showroomName, String carId) async {
    final link = 'https://car-showrooms-sa.web.app/c/$carId';
    final msg = Uri.encodeComponent('شف هذه السيارة في تطبيق شاري:\n$title\nالسعر: ${_formatPrice(price)} ر.س\nالمعرض: $showroomName\n$link');
    final uri = Uri.parse('https://wa.me/?text=$msg');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final carId = _readField(car, ['id']).toString();
    final make = _readField(car, ['make']).toString();
    final model = _readField(car, ['model']).toString();
    final year = _readField(car, ['year']).toString();
    final price = _readPrice(car);
    final monthly = _estimateMonthly(price);
    final srId = _readField(car, ['showroom_id', 'showroomId']).toString();
    final srName = _readField(car, ['showroom_name', 'showroomName'], fallback: 'معرض معتمد').toString();
    final ownerUid = _readField(car, ['owner_uid', 'ownerUid']).toString();
    final regionId = _readField(car, ['region_id', 'regionId'], fallback: 'riyadh').toString();
    final hub = _readField(car, ['city_hub', 'cityHub']).toString();
    final body = _readField(car, ['body_condition', 'bodyCondition'], fallback: 'بودي وكالة بالكامل').toString();
    final mileage = _readField(car, ['mileage'], fallback: 0);
    final images = _readImages(car);
    final title = '$make $model $year'.trim();
    final fee = PricingRules.reservationFee(price);

    return Scaffold(
      backgroundColor: LuxuryColors.background,
      appBar: AppBar(
        backgroundColor: LuxuryColors.navy,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'مشاركة رابط السيارة',
            icon: const Icon(Icons.share_outlined, color: LuxuryColors.gold),
            onPressed: () => _shareOnWhatsApp(title, price, srName, carId),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (images.isNotEmpty) ...[
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(images[i], width: 340, height: 240, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(18), border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('$srName · ${findRegion(regionId).nameAr} · $hub', style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                    const Divider(color: Colors.white24, height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('سعر الكاش', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('${_formatPrice(price)} ر.س', style: const TextStyle(color: LuxuryColors.gold, fontSize: 24, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('القسط التقديري', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('${_formatPrice(monthly)} ر.س / شهرياً', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: LuxuryColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxuryColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مواصفات السيارة وضمان الحجز', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
                    const SizedBox(height: 12),
                    Text('حالة البودي: $body · العداد: $mileage كم', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('• رقم المعرض المباشر محجوب لحماية حقوق الطرفين، ويُفتح فوراً بعد دفع عربون الجدية ($fee ر.س رسوم حجز وضمان لصالح منصة «شاري» — مستردة 100% عند عدم التوفر أو وجود عيب).', style: const TextStyle(fontSize: 13, color: LuxuryColors.textSecondary)),
                    const SizedBox(height: 6),
                    const Text('• التجميد الذكي: يبدأ التجميد بعد تأكيد المعرض (4 ساعات داخل نفس المدينة، و24 ساعة لخارج المنطقة).', style: TextStyle(fontSize: 13, color: LuxuryColors.textSecondary)),
                    const SizedBox(height: 6),
                    const Text('• يلتزم المعرض بالرد خلال ساعتين، وإلا يُسترجع العربون تلقائياً لحسابك.', style: TextStyle(fontSize: 13, color: LuxuryColors.success, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: LuxuryColors.navy,
                    foregroundColor: LuxuryColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => BuyerVerificationSheet.show(
                    context,
                    carId: carId,
                    carTitle: title,
                    carPrice: price,
                    showroomId: srId,
                    showroomName: srName,
                    showroomOwnerUid: ownerUid,
                    regionId: regionId,
                  ),
                  icon: const Icon(Icons.lock_outline),
                  label: Text('احجز السيارة الآن (عربون ضمان $fee ر.س)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفحة صالة المعرض المستقلة
class ShowroomProfileScreen extends StatelessWidget {
  final ShowroomModel showroom;
  final List<dynamic> cars;

  const ShowroomProfileScreen({super.key, required this.showroom, required this.cars});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxuryColors.background,
      appBar: AppBar(
        backgroundColor: LuxuryColors.navy,
        foregroundColor: Colors.white,
        title: Text(showroom.commercialName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: LuxuryColors.navy, borderRadius: BorderRadius.circular(18), border: Border.all(color: LuxuryColors.gold.withValues(alpha: 0.45))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(showroom.commercialName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                        if (showroom.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: LuxuryColors.gold, borderRadius: BorderRadius.circular(8)),
                            child: const Text('معرض موثق ✓', style: TextStyle(color: LuxuryColors.navy, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${findRegion(showroom.regionId).nameAr} · ${showroom.cityHub} · سجل: ${showroom.crNumber}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('سيارات الصالة (${cars.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LuxuryColors.navy)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: cars.map((car) => _CarListingCard(car: car)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
