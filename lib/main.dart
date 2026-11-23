import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ShowroomPlatformApp());
}

class AppColors {
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color primary = Color(0xFF1E3A8A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF166534);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFF92400E);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFF991B1B);
}

class SecurityGuard {
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>|&[^;]+;');
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  static String sanitizeText(String input, {int maxLength = 120}) {
    final cleaned = input.replaceAll(_htmlTagRegex, '').replaceAll(_controlChars, '').trim();
    if (cleaned.length <= maxLength) return cleaned;
    return cleaned.substring(0, maxLength).trim();
  }

  static String? validateRequiredText(String? value, String fieldLabel, {int min = 2, int max = 100}) {
    final clean = sanitizeText(value ?? '', maxLength: max);
    if (clean.isEmpty) return 'يرجى إدخال $fieldLabel.';
    if (clean.length < min) return 'يجب ألا يقل $fieldLabel عن $min أحرف.';
    return null;
  }

  static String? validatePositiveInt(String? value, String fieldLabel, {int min = 1, int max = 5000000}) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'يرجى إدخال رقم صحيح في $fieldLabel.';
    if (parsed < min || parsed > max) return 'قيمة $fieldLabel يجب أن تكون بين $min و $max.';
    return null;
  }

  static String? validateYear(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    final currentYear = DateTime.now().year + 1;
    if (parsed == null || parsed < 1990 || parsed > currentYear) {
      return 'يرجى إدخال سنة صنع صحيحة (1990 - $currentYear).';
    }
    return null;
  }

  static String? validateCrNumber(String? value) {
    final digitsOnly = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) return 'رقم السجل التجاري يجب أن يتكون من 10 أرقام.';
    return null;
  }
}

class SafeErrorMapper {
  static String toUserMessage(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return 'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'لا تملك الصلاحية لتنفيذ هذا الإجراء حالياً.';
        case 'unavailable':
          return 'الخدمة غير متاحة مؤقتاً. يرجى المحاولة بعد قليل.';
        case 'network-request-failed':
          return 'حدث انقطاع في الشبكة أثناء الاتصال بقاعدة البيانات.';
        default:
          return 'تعذر إتمام العملية على قاعدة البيانات. يرجى المحاولة مرة أخرى.';
      }
    }
    return 'حدث خطأ غير متوقع أثناء معالجة الطلب. يرجى المحاولة مرة أخرى.';
  }
}

class RegionInfo {
  final String id;
  final String nameAr;
  final String defaultHub;
  final double lat;
  final double lng;

  const RegionInfo({
    required this.id,
    required this.nameAr,
    required this.defaultHub,
    required this.lat,
    required this.lng,
  });
}

const List<RegionInfo> kSaudiRegions = [
  RegionInfo(id: 'riyadh', nameAr: 'منطقة الرياض', defaultHub: 'معارض القادسية', lat: 24.7136, lng: 46.6753),
  RegionInfo(id: 'eastern', nameAr: 'المنطقة الشرقية', defaultHub: 'معارض الدمام (ضاحية الملك فهد)', lat: 26.4207, lng: 50.0888),
  RegionInfo(id: 'makkah', nameAr: 'منطقة مكة المكرمة', defaultHub: 'معارض الجوهرة (جدة)', lat: 21.4858, lng: 39.1925),
  RegionInfo(id: 'madinah', nameAr: 'منطقة المدينة المنورة', defaultHub: 'معارض المدينة', lat: 24.5247, lng: 39.5692),
  RegionInfo(id: 'qassim', nameAr: 'منطقة القصيم', defaultHub: 'معارض بريدة', lat: 26.3260, lng: 43.9750),
  RegionInfo(id: 'asir', nameAr: 'منطقة عسير', defaultHub: 'معارض خميس مشيط', lat: 18.2465, lng: 42.5117),
  RegionInfo(id: 'tabuk', nameAr: 'منطقة تبوك', defaultHub: 'معارض تبوك', lat: 28.3835, lng: 36.5662),
  RegionInfo(id: 'hail', nameAr: 'منطقة حائل', defaultHub: 'معارض حائل', lat: 27.5114, lng: 41.7208),
  RegionInfo(id: 'northern', nameAr: 'الحدود الشمالية', defaultHub: 'معارض عرعر', lat: 30.9753, lng: 41.0381),
  RegionInfo(id: 'jazan', nameAr: 'منطقة جازان', defaultHub: 'معارض جازان', lat: 16.8894, lng: 42.5706),
  RegionInfo(id: 'najran', nameAr: 'منطقة نجران', defaultHub: 'معارض نجران', lat: 17.4924, lng: 44.1277),
  RegionInfo(id: 'bahah', nameAr: 'منطقة الباحة', defaultHub: 'معارض الباحة', lat: 20.0129, lng: 41.4677),
  RegionInfo(id: 'jouf', nameAr: 'منطقة الجوف', defaultHub: 'معارض سكاكا', lat: 29.9697, lng: 40.2064),
];

RegionInfo findRegion(String id) {
  return kSaudiRegions.firstWhere((r) => r.id == id, orElse: () => kSaudiRegions.first);
}

class PricingCalculator {
  static Map<String, int> estimateTow({
    required String fromRegionId,
    required String toRegionId,
    required bool isBackhaul,
  }) {
    if (fromRegionId == toRegionId) {
      final baseSameCity = 150;
      final cost = isBackhaul ? (baseSameCity * 0.70).round() : baseSameCity;
      return {'km': 25, 'cost': cost};
    }

    final origin = findRegion(fromRegionId);
    final destination = findRegion(toRegionId);

    const degToRad = 0.017453292519943295;
    final dLat = (destination.lat - origin.lat) * degToRad;
    final dLng = (destination.lng - origin.lng) * degToRad;
    final haversine = pow(sin(dLat / 2), 2) +
        cos(origin.lat * degToRad) * cos(destination.lat * degToRad) * pow(sin(dLng / 2), 2);
    final directKm = 12742.0 * asin(min(1.0, sqrt(haversine.toDouble())));
    final roadKm = max(30, (directKm * 1.25).round());

    int towFee = (150 + (roadKm * 1.2)).round();
    if (isBackhaul) {
      towFee = (towFee * 0.70).round();
    }
    return {'km': roadKm, 'cost': towFee};
  }

  static int serviceFeeFor(int baseAmount) {
    return ((baseAmount * 0.025) + 2.0).ceil();
  }
}

class CarListingModel {
  final String id;
  final String make;
  final String model;
  final int year;
  final int price;
  final String condition;
  final int mileage;
  final String bodyCondition;
  final String specType;
  final String regionId;
  final String cityHub;
  final String showroomId;
  final String showroomName;
  final bool isShowroomVerified;
  final String status;
  final bool isFeatured;
  final bool hasBackhaulTow;

  const CarListingModel({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.price,
    required this.condition,
    required this.mileage,
    required this.bodyCondition,
    required this.specType,
    required this.regionId,
    required this.cityHub,
    required this.showroomId,
    required this.showroomName,
    required this.isShowroomVerified,
    required this.status,
    required this.isFeatured,
    required this.hasBackhaulTow,
  });

  factory CarListingModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CarListingModel(
      id: doc.id,
      make: (data['make'] ?? '').toString(),
      model: (data['model'] ?? '').toString(),
      year: (data['year'] is num) ? (data['year'] as num).toInt() : 2025,
      price: (data['price'] is num) ? (data['price'] as num).toInt() : 0,
      condition: (data['condition'] ?? 'used').toString(),
      mileage: (data['mileage'] is num) ? (data['mileage'] as num).toInt() : 0,
      bodyCondition: (data['body_condition'] ?? 'حالة معلنة').toString(),
      specType: (data['spec_type'] ?? 'saudi').toString(),
      regionId: (data['region_id'] ?? 'riyadh').toString(),
      cityHub: (data['city_hub'] ?? '').toString(),
      showroomId: (data['showroom_id'] ?? '').toString(),
      showroomName: (data['showroom_name'] ?? 'معرض معتمد').toString(),
      isShowroomVerified: data['is_showroom_verified'] == true,
      status: (data['status'] ?? 'available').toString(),
      isFeatured: data['is_featured'] == true,
      hasBackhaulTow: data['has_backhaul_tow'] == true,
    );
  }

  String get title => '$make $model $year';
  String get conditionLabel => condition == 'new' ? 'جديدة' : 'مستعملة';

  String get specLabel {
    switch (specType) {
      case 'saudi':
        return 'وارد سعودي';
      case 'gulf':
        return 'وارد خليجي';
      case 'us':
        return 'وارد أمريكي';
      case 'korean':
        return 'وارد كوري';
      default:
        return 'مواصفات معتمدة';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'reserved':
        return 'محجوزة';
      case 'sold':
        return 'مباعة';
      default:
        return 'متاحة';
    }
  }

  String get qrPayload =>
      'SA-SHOWROOM|CAR:$id|SHOWROOM:$showroomId|VEHICLE:$make-$model-$year|PRICE:$price';
}

class ShowroomRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CarListingModel>> watchCars({int limit = 25}) {
    return _firestore
        .collection('cars')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(CarListingModel.fromDoc).toList());
  }

  Future<void> seedStarterInventoryIfEmpty() async {
    final existing = await _firestore.collection('cars').limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final samples = [
      {
        'make': 'تويوتا',
        'model': 'كامري قراندي',
        'year': 2026,
        'price': 142000,
        'condition': 'new',
        'mileage': 0,
        'body_condition': 'حالة الوكالة - أصفار',
        'spec_type': 'saudi',
        'region_id': 'riyadh',
        'city_hub': 'معارض القادسية',
        'showroom_id': 'sr_qadisiyah_01',
        'showroom_name': 'معرض الأفق للسيارات',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': true,
        'has_backhaul_tow': true,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'make': 'هيونداي',
        'model': 'أزيرا كاليجرافي',
        'year': 2025,
        'price': 129500,
        'condition': 'used',
        'mileage': 16400,
        'body_condition': 'خالية من الرش والحوادث',
        'spec_type': 'korean',
        'region_id': 'eastern',
        'city_hub': 'معارض الدمام (ضاحية الملك فهد)',
        'showroom_id': 'sr_dammam_02',
        'showroom_name': 'معرض الساحل الشرقي',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': false,
        'has_backhaul_tow': false,
        'created_at': FieldValue.serverTimestamp(),
      },
      {
        'make': 'فورد',
        'model': 'تورس تيتانيوم',
        'year': 2024,
        'price': 104000,
        'condition': 'used',
        'mileage': 32000,
        'body_condition': 'فحص شاصي ومحركات سليم',
        'spec_type': 'us',
        'region_id': 'makkah',
        'city_hub': 'معارض الجوهرة (جدة)',
        'showroom_id': 'sr_jeddah_03',
        'showroom_name': 'معرض المرسى للسيارات',
        'is_showroom_verified': true,
        'status': 'available',
        'is_featured': false,
        'has_backhaul_tow': true,
        'created_at': FieldValue.serverTimestamp(),
      },
    ];

    for (final item in samples) {
      batch.set(_firestore.collection('cars').doc(), item);
    }
    await batch.commit();
  }

  Future> createTransaction({
    required String type,
    required String title,
    required CarListingModel car,
    required String buyerRegionId,
    required int baseAmount,
    required double partnerShareRatio,
  }) async {
    final fee = PricingCalculator.serviceFeeFor(baseAmount);
    final totalPaid = baseAmount + fee;
    final partnerShare = (baseAmount * partnerShareRatio).round();
    final platformCommission = baseAmount - partnerShare;
    final otpCode = (1000 + Random().nextInt(9000)).toString();

    final docRef = await _firestore.collection('transactions').add({
      'type': type,
      'title': title,
      'car_id': car.id,
      'car_title': car.title,
      'showroom_id': car.showroomId,
      'buyer_region_id': buyerRegionId,
      'base_amount': baseAmount,
      'service_fee': fee,
      'gross_amount': totalPaid,
      'partner_share': partnerShare,
      'platform_commission': platformCommission,
      'delivery_otp': otpCode,
      'status': 'pending_confirmation',
      'created_at': FieldValue.serverTimestamp(),
    });

    return {
      'tx_id': docRef.id,
      'base_amount': baseAmount,
      'service_fee': fee,
      'gross_amount': totalPaid,
      'partner_share': partnerShare,
      'platform_commission': platformCommission,
      'delivery_otp': otpCode,
    };
  }

  Future<String> registerShowroom({
    required String showroomName,
    required String crNumber,
    required String regionId,
    required String cityHub,
    required String contactPhone,
  }) async {
    final docRef = await _firestore.collection('showrooms').add({
      'name': SecurityGuard.sanitizeText(showroomName, maxLength: 90),
      'cr_number': SecurityGuard.sanitizeText(crNumber, maxLength: 10),
      'region_id': regionId,
      'city_hub': SecurityGuard.sanitizeText(cityHub, maxLength: 90),
      'contact_phone': SecurityGuard.sanitizeText(contactPhone, maxLength: 15),
      'is_verified': true,
      'plan_id': 'showroom_free',
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<String> addCarToInventory({
    required String showroomId,
    required String showroomName,
    required String regionId,
    required String cityHub,
    required String make,
    required String model,
    required int year,
    required int price,
    required String condition,
    required int mileage,
    required String bodyCondition,
    required String specType,
    required bool isFeatured,
    required bool hasBackhaulTow,
  }) async {
    final docRef = await _firestore.collection('cars').add({
      'make': SecurityGuard.sanitizeText(make, maxLength: 40),
      'model': SecurityGuard.sanitizeText(model, maxLength: 50),
      'year': year,
      'price': price,
      'condition': condition,
      'mileage': condition == 'new' ? 0 : mileage,
      'body_condition': SecurityGuard.sanitizeText(bodyCondition, maxLength: 120),
      'spec_type': specType,
      'region_id': regionId,
      'city_hub': SecurityGuard.sanitizeText(cityHub, maxLength: 80),
      'showroom_id': SecurityGuard.sanitizeText(showroomId, maxLength: 60),
      'showroom_name': SecurityGuard.sanitizeText(showroomName, maxLength: 90),
      'is_showroom_verified': true,
      'status': 'available',
      'is_featured': isFeatured,
      'has_backhaul_tow': hasBackhaulTow,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateCarStatus(String carId, String nextStatus) async {
    const allowed = {'available', 'reserved', 'sold'};
    if (!allowed.contains(nextStatus)) {
      throw ArgumentError('حالة المركبة غير صالحة.');
    }
    await _firestore.collection('cars').doc(carId).update({
      'status': nextStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}

class ShowroomPlatformApp extends StatefulWidget {
  const ShowroomPlatformApp({super.key});

  @override
  State<ShowroomPlatformApp> createState() => _ShowroomPlatformAppState();
}

class _ShowroomPlatformAppState extends State<ShowroomPlatformApp> {
  int _currentTab = 0;
  final ShowroomRepository _repository = ShowroomRepository();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'منصة معارض السيارات والسطحات',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            secondary: AppColors.textSecondary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            error: AppColors.danger,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            shape: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text(
              'منصة المعارض والسطحات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.primary,
                    selectedForegroundColor: AppColors.onPrimary,
                    backgroundColor: AppColors.surfaceSubtle,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  segments: const [
                    ButtonSegment<int>(value: 0, label: Text('سوق المشتري')),
                    ButtonSegment<int>(value: 1, label: Text('بوابة المعارض')),
                  ],
                  selected: {_currentTab},
                  onSelectionChanged: (selection) {
                    setState(() => _currentTab = selection.first);
                  },
                ),
              ),
            ],
          ),
          body: _currentTab == 0
              ? BuyerMarketplaceScreen(repository: _repository)
              : ShowroomPortalScreen(repository: _repository),
        ),
      ),
    );
  }
}

class LoadingStateView extends StatelessWidget {
  final String message;
  const LoadingStateView({super.key, this.message = 'جاري تحميل البيانات...'});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 132,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 180, color: AppColors.surfaceSubtle),
            const SizedBox(height: 10),
            Container(height: 12, width: 240, color: AppColors.surfaceSubtle),
            const Spacer(),
            Container(height: 28, width: double.infinity, color: AppColors.surfaceSubtle),
          ],
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.35), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text(
                'تعذر عرض البيانات',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrCodeMatrixPainter extends CustomPainter {
  final String payload;
  const QrCodeMatrixPainter({required this.payload});

  @override
  void paint(Canvas canvas, Size size) {
    const int gridCount = 21;
    final double cellSize = size.width / gridCount;
    final Paint darkPaint = Paint()..color = AppColors.textPrimary;

    bool isFinderCell(int r, int c) {
      final topLeft = r < 7 && c < 7;
      final topRight = r < 7 && c >= gridCount - 7;
      final bottomLeft = r >= gridCount - 7 && c < 7;
      if (!topLeft && !topRight && !bottomLeft) return false;

      int lr = r;
      int lc = c;
      if (topRight) lc = c - (gridCount - 7);
      if (bottomLeft) lr = r - (gridCount - 7);

      final isOuterBorder = lr == 0 || lr == 6 || lc == 0 || lc == 6;
      final isInnerDot = lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4;
      return isOuterBorder || isInnerDot;
    }

    int seed = 17;
    for (int i = 0; i < payload.length; i++) {
      seed = (seed * 31 + payload.codeUnitAt(i)) & 0x7fffffff;
    }

    for (int r = 0; r < gridCount; r++) {
      for (int c = 0; c < gridCount; c++) {
        if (isFinderCell(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            darkPaint,
          );
          continue;
        }
        final hash = ((r * 37 + c * 73 + seed) * 1103515245 + 12345) & 0x7fffffff;
        if (hash % 3 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            darkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrCodeMatrixPainter oldDelegate) {
    return oldDelegate.payload != payload;
  }
}

void showCarQrStickerDialog(BuildContext context, CarListingModel car) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'ملصق QR الذكي للمركبة',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      car.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${car.showroomName} - ${car.cityHub}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'السعر: ${car.price} ريال',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderStrong),
                      ),
                      child: SizedBox(
                        width: 156,
                        height: 156,
                        child: CustomPaint(
                          painter: QrCodeMatrixPainter(payload: car.qrPayload),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      car.qrPayload,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'يمكن طباعة هذا الملصق ووضعه على زجاج المركبة لتمكين المتسوقين من عرض المواصفات وحساب الشحن وطلب الفحص أو الحجز فوراً.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ),
  );
}

class BuyerMarketplaceScreen extends StatefulWidget {
  final ShowroomRepository repository;
  const BuyerMarketplaceScreen({super.key, required this.repository});

  @override
  State<BuyerMarketplaceScreen> createState() => _BuyerMarketplaceScreenState();
}

class _BuyerMarketplaceScreenState extends State<BuyerMarketplaceScreen> {
  String _buyerRegionId = 'eastern';
  String _filterRegionId = 'all';
  String _filterCondition = 'all';
  String _filterSpec = 'all';
  int _streamKey = 0;
  bool _seeding = false;

  Future<void> _seedSampleData() async {
    setState(() => _seeding = true);
    try {
      await widget.repository.seedStarterInventoryIfEmpty();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت تهيئة بيانات السوق الأولية بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مدينة التسليم لحساب السطحة:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _buyerRegionId,
                      items: kSaudiRegions
                          .map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.nameAr)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _buyerRegionId = val);
                      },
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _seeding ? null : _seedSampleData,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: Text(_seeding ? 'جاري التحميل...' : 'إضافة مركبات نموذجية'),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  value: _filterRegionId,
                  items: [
                    const DropdownMenuItem<String>(value: 'all', child: Text('جميع المناطق (13)')),
                    ...kSaudiRegions.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.nameAr))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterRegionId = val);
                  },
                ),
              ),
              _FilterPill(
                label: 'الكل',
                selected: _filterCondition == 'all',
                onTap: () => setState(() => _filterCondition = 'all'),
              ),
              _FilterPill(
                label: 'جديدة',
                selected: _filterCondition == 'new',
                onTap: () => setState(() => _filterCondition = 'new'),
              ),
              _FilterPill(
                label: 'مستعملة',
                selected: _filterCondition == 'used',
                onTap: () => setState(() => _filterCondition = 'used'),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  value: _filterSpec,
                  items: const [
                    DropdownMenuItem<String>(value: 'all', child: Text('جميع الواردات')),
                    DropdownMenuItem<String>(value: 'saudi', child: Text('وارد سعودي')),
                    DropdownMenuItem<String>(value: 'gulf', child: Text('وارد خليجي')),
                    DropdownMenuItem<String>(value: 'us', child: Text('وارد أمريكي')),
                    DropdownMenuItem<String>(value: 'korean', child: Text('وارد كوري')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterSpec = val);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CarListingModel>>(
            key: ValueKey(_streamKey),
            stream: widget.repository.watchCars(limit: 25),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(
                  message: SafeErrorMapper.toUserMessage(snapshot.error!),
                  onRetry: () => setState(() => _streamKey++),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const LoadingStateView(message: 'جاري تحميل المركبات المعروضة...');
              }

              final allCars = snapshot.data ?? const <CarListingModel>[];
              final filtered = allCars.where((car) {
                if (_filterRegionId != 'all' && car.regionId != _filterRegionId) return false;
                if (_filterCondition != 'all' && car.condition != _filterCondition) return false;
                if (_filterSpec != 'all' && car.specType != _filterSpec) return false;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return EmptyStateView(
                  title: 'لا توجد مركبات مطابقة للتصفية الحالية',
                  description: 'يمكنك تغيير خيارات المنطقة أو الحالة، أو إضافة مركبات نموذجية لبدء تجربة السوق.',
                  actionLabel: 'إضافة مركبات نموذجية',
                  onAction: _seedSampleData,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final car = filtered[index];
                  final tow = PricingCalculator.estimateTow(
                    fromRegionId: car.regionId,
                    toRegionId: _buyerRegionId,
                    isBackhaul: car.hasBackhaulTow,
                  );
                  final int towCost = tow['cost']!;
                  final int distanceKm = tow['km']!;
                  final int totalDelivered = car.price + towCost;

                  return _CarListingCard(
                    car: car,
                    distanceKm: distanceKm,
                    towCost: towCost,
                    totalDelivered: totalDelivered,
                    onOpenDetails: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: CarDetailsScreen(
                              repository: widget.repository,
                              car: car,
                              buyerRegionId: _buyerRegionId,
                              distanceKm: distanceKm,
                              towCost: towCost,
                            ),
                          ),
                        ),
                      );
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

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CarListingCard extends StatelessWidget {
  final CarListingModel car;
  final int distanceKm;
  final int towCost;
  final int totalDelivered;
  final VoidCallback onOpenDetails;

  const _CarListingCard({
    required this.car,
    required this.distanceKm,
    required this.towCost,
    required this.totalDelivered,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpenDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaTag(text: car.conditionLabel, highlight: car.condition == 'new'),
                  _MetaTag(text: car.specLabel),
                  _MetaTag(text: car.statusLabel),
                  if (car.hasBackhaulTow)
                    const _MetaTag(text: 'سطحة خط رجعة - خصم 30%', successStyle: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 84,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.directions_car_outlined, size: 32, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${car.showroomName} · ${car.cityHub}${car.isShowroomVerified ? ' · معرض موثق' : ''}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سعر المركبة: ${car.price} ريال',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'الشحن ($distanceKm كم): $towCost ريال  |  الإجمالي الواصل للتسليم: $totalDelivered ريال',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ),
                  const Text(
                    'التفاصيل',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String text;
  final bool highlight;
  final bool successStyle;

  const _MetaTag({required this.text, this.highlight = false, this.successStyle = false});

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surface;
    Color fg = AppColors.textSecondary;
    Color borderCol = AppColors.border;

    if (successStyle) {
      bg = AppColors.successBg;
      fg = AppColors.success;
      borderCol = AppColors.success.withValues(alpha: 0.3);
    } else if (highlight) {
      bg = AppColors.primary.withValues(alpha: 0.08);
      fg = AppColors.primary;
      borderCol = AppColors.primary.withValues(alpha: 0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderCol),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class CarDetailsScreen extends StatefulWidget {
  final ShowroomRepository repository;
  final CarListingModel car;
  final String buyerRegionId;
  final int distanceKm;
  final int towCost;

  const CarDetailsScreen({
    super.key,
    required this.repository,
    required this.car,
    required this.buyerRegionId,
    required this.distanceKm,
    required this.towCost,
  });

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  bool _submitting = false;

  Future<void> _executeOrder({
    required String type,
    required String title,
    required int baseAmount,
    required double partnerRatio,
  }) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.repository.createTransaction(
        type: type,
        title: title,
        car: widget.car,
        buyerRegionId: widget.buyerRegionId,
        baseAmount: baseAmount,
        partnerShareRatio: partnerRatio,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            title: const Text(
              'تم تسجيل الطلب وتوليد رمز التسليم',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الخدمة: $title', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('المبلغ الأساسي: ${result['base_amount']} ريال'),
                Text('رسوم الخدمة (2.5% + 2 ريال): ${result['service_fee']} ريال'),
                const Divider(height: 18),
                Text(
                  'الإجمالي المستحق: ${result['gross_amount']} ريال',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text('حصة الشريك المنفذ: ${result['partner_share']} ريال'),
                Text('عمولة المنصة: ${result['platform_commission']} ريال'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'رمز التحقق والتسليم (OTP): ${result['delivery_otp']}\nلا يتم تحرير مستحقات التنفيذ إلا بعد تأكيد التسليم بهذا الرمز.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final bookingFee = PricingCalculator.serviceFeeFor(99);
    final inspectionFee = PricingCalculator.serviceFeeFor(199);
    final towServiceFee = PricingCalculator.serviceFeeFor(widget.towCost);

    return Scaffold(
      appBar: AppBar(
        title: Text(car.title),
        actions: [
          IconButton(
            tooltip: 'عرض ملصق QR',
            onPressed: () => showCarQrStickerDialog(context, car),
            icon: const Icon(Icons.qr_code_2),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'سعر المعرض: ${car.price} ريال',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const Divider(height: 22),
                  Text('الحالة: ${car.conditionLabel}${car.condition == 'used' ? ' (${car.mileage} كم)' : ''}'),
                  const SizedBox(height: 6),
                  Text('المواصفات: ${car.specLabel}'),
                  const SizedBox(height: 6),
                  Text('حالة البودي: ${car.bodyCondition}'),
                  const SizedBox(height: 6),
                  Text('المعرض: ${car.showroomName} - ${car.cityHub}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'الخدمات الفورية للمشتري',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            _ServiceActionTile(
              title: 'حجز جدية المركبة لمدة 4 ساعات (99 ريال)',
              subtitle: 'تثبيت المركبة مؤقتاً للمشتري (+$bookingFee ريال رسوم خدمة)',
              buttonLabel: 'حجز الآن',
              disabled: _submitting,
              onPressed: () => _executeOrder(
                type: 'car_booking',
                title: 'حجز جدية مركبة (4 ساعات)',
                baseAmount: 99,
                partnerRatio: 0.0,
              ),
            ),
            _ServiceActionTile(
              title: 'طلب فحص وتوثيق فيديو عن بُعد (199 ريال)',
              subtitle: 'فحص ميداني في المعرض وتقرير مصور (+$inspectionFee ريال رسوم خدمة)',
              buttonLabel: 'طلب الفحص',
              disabled: _submitting,
              onPressed: () => _executeOrder(
                type: 'car_inspection',
                title: 'فحص مركبة عن بُعد',
                baseAmount: 199,
                partnerRatio: 0.80,
              ),
            ),
            _ServiceActionTile(
              title: 'طلب سطحة نقل (${widget.distanceKm} كم - ${widget.towCost} ريال)',
              subtitle: 'توصيل إلى مدينة المشتري مع رمز تسليم OTP (+$towServiceFee ريال رسوم خدمة)',
              buttonLabel: 'طلب السطحة',
              disabled: _submitting,
              onPressed: () => _executeOrder(
                type: 'tow_trip',
                title: 'نقل مركبة عبر سطحة',
                baseAmount: widget.towCost,
                partnerRatio: 0.90,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool disabled;
  final VoidCallback onPressed;

  const _ServiceActionTile({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.disabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: disabled ? null : onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class ShowroomPortalScreen extends StatefulWidget {
  final ShowroomRepository repository;
  const ShowroomPortalScreen({super.key, required this.repository});

  @override
  State<ShowroomPortalScreen> createState() => _ShowroomPortalScreenState();
}

class _ShowroomPortalScreenState extends State<ShowroomPortalScreen> {
  String _activeShowroomId = 'sr_qadisiyah_01';
  String _activeShowroomName = 'معرض الأفق للسيارات';
  String _activeRegionId = 'riyadh';
  String _activeCityHub = 'معارض القادسية';

  final GlobalKey<FormState> _regFormKey = GlobalKey<FormState>();
  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regCrCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regHubCtrl = TextEditingController(text: 'معارض القادسية');
  String _regRegionId = 'riyadh';
  bool _registering = false;

  final GlobalKey<FormState> _carFormKey = GlobalKey<FormState>();
  final TextEditingController _makeCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  final TextEditingController _yearCtrl = TextEditingController(text: '2026');
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _mileageCtrl = TextEditingController(text: '0');
  final TextEditingController _bodyCtrl = TextEditingController(text: 'حالة الوكالة');
  String _carCondition = 'new';
  String _carSpec = 'saudi';
  bool _carFeatured = false;
  bool _carBackhaul = false;
  bool _savingCar = false;
  int _streamKey = 0;

  @override
  void dispose() {
    _regNameCtrl.dispose();
    _regCrCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regHubCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _priceCtrl.dispose();
    _mileageCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitShowroomRegistration() async {
    if (!_regFormKey.currentState!.validate()) return;
    setState(() => _registering = true);
    try {
      final newId = await widget.repository.registerShowroom(
        showroomName: _regNameCtrl.text,
        crNumber: _regCrCtrl.text,
        regionId: _regRegionId,
        cityHub: _regHubCtrl.text,
        contactPhone: _regPhoneCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _activeShowroomId = newId;
        _activeShowroomName = SecurityGuard.sanitizeText(_regNameCtrl.text, maxLength: 90);
        _activeRegionId = _regRegionId;
        _activeCityHub = SecurityGuard.sanitizeText(_regHubCtrl.text, maxLength: 90);
        _regNameCtrl.clear();
        _regCrCtrl.clear();
        _regPhoneCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل المعرض وتفعيل حسابه بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _submitNewCar() async {
    if (!_carFormKey.currentState!.validate()) return;
    setState(() => _savingCar = true);
    try {
      final year = int.parse(_yearCtrl.text.trim());
      final price = int.parse(_priceCtrl.text.trim());
      final mileage = int.tryParse(_mileageCtrl.text.trim()) ?? 0;

      await widget.repository.addCarToInventory(
        showroomId: _activeShowroomId,
        showroomName: _activeShowroomName,
        regionId: _activeRegionId,
        cityHub: _activeCityHub,
        make: _makeCtrl.text,
        model: _modelCtrl.text,
        year: year,
        price: price,
        condition: _carCondition,
        mileage: mileage,
        bodyCondition: _bodyCtrl.text,
        specType: _carSpec,
        isFeatured: _carFeatured,
        hasBackhaulTow: _carBackhaul,
      );
      if (!mounted) return;
      _makeCtrl.clear();
      _modelCtrl.clear();
      _priceCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المركبة إلى مخزون المعرض وتوليد رمز QR الخاص بها.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _savingCar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المعرض النشط حالياً', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '$_activeShowroomName · $_activeCityHub',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'حساب معرض موثق',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: _regFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تسجيل معرض جديد (تسجيل ذاتي)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _regNameCtrl,
                        decoration: const InputDecoration(labelText: 'اسم المعرض'),
                        validator: (v) => SecurityGuard.validateRequiredText(v, 'اسم المعرض'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextFormField(
                        controller: _regCrCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'رقم السجل التجاري (10 أرقام)'),
                        validator: SecurityGuard.validateCrNumber,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: _regRegionId,
                        decoration: const InputDecoration(labelText: 'المنطقة'),
                        items: kSaudiRegions
                            .map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.nameAr)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _regRegionId = val;
                              _regHubCtrl.text = findRegion(val).defaultHub;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextFormField(
                        controller: _regHubCtrl,
                        decoration: const InputDecoration(labelText: 'تجمع المعارض / الحي'),
                        validator: (v) => SecurityGuard.validateRequiredText(v, 'تجمع المعارض'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextFormField(
                        controller: _regPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم التواصل'),
                        validator: (v) => SecurityGuard.validateRequiredText(v, 'رقم التواصل', min: 9, max: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _registering ? null : _submitShowroomRegistration,
                    child: Text(_registering ? 'جاري التسجيل...' : 'حفظ وتفعيل المعرض'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: _carFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إضافة مركبة إلى المخزون وتوليد ملصق QR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextFormField(
                        controller: _makeCtrl,
                        decoration: const InputDecoration(labelText: 'الشركة الصانعة'),
                        validator: (v) => SecurityGuard.validateRequiredText(v, 'الشركة الصانعة'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextFormField(
                        controller: _modelCtrl,
                        decoration: const InputDecoration(labelText: 'الطراز والفئة'),
                        validator: (v) => SecurityGuard.validateRequiredText(v, 'الطراز'),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: _yearCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'سنة الصنع'),
                        validator: SecurityGuard.validateYear,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'السعر (ريال)'),
                        validator: (v) => SecurityGuard.validatePositiveInt(v, 'السعر', min: 5000, max: 5000000),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        value: _carCondition,
                        decoration: const InputDecoration(labelText: 'حالة المركبة'),
                        items: const [
                          DropdownMenuItem<String>(value: 'new', child: Text('جديدة')),
                          DropdownMenuItem<String>(value: 'used', child: Text('مستعملة')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _carCondition = val);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _mileageCtrl,
                        enabled: _carCondition == 'used',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'الممشى (كم)'),
                        validator: (v) {
                          if (_carCondition == 'new') return null;
                          return SecurityGuard.validatePositiveInt(v, 'الممشى', min: 1, max: 900000);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _carSpec,
                        decoration: const InputDecoration(labelText: 'نوع الوارد'),
                        items: const [
                          DropdownMenuItem<String>(value: 'saudi', child: Text('وارد سعودي')),
                          DropdownMenuItem<String>(value: 'gulf', child: Text('وارد خليجي')),
                          DropdownMenuItem<String>(value: 'us', child: Text('وارد أمريكي')),
                          DropdownMenuItem<String>(value: 'korean', child: Text('وارد كوري')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _carSpec = val);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _bodyCtrl,
                        decoration: const InputDecoration(labelText: 'حالة البودي والفحص'),
                        validator: (v) => SecurityGuard.validateRequiredText(v, 'حالة البودي', min: 3, max: 120),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _carFeatured,
                          onChanged: (v) => setState(() => _carFeatured = v ?? false),
                        ),
                        const Text('إبراز المركبة في المقدمة'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _carBackhaul,
                          onChanged: (v) => setState(() => _carBackhaul = v ?? false),
                        ),
                        const Text('تفعيل خصم سطحة خط الرجعة (30%)'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _savingCar ? null : _submitNewCar,
                    child: Text(_savingCar ? 'جاري النشر...' : 'نشر المركبة في المخزون'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إدارة المخزون وطباعة ملصقات QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<CarListingModel>>(
                key: ValueKey(_streamKey),
                stream: widget.repository.watchCars(limit: 25),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorStateView(
                      message: SafeErrorMapper.toUserMessage(snapshot.error!),
                      onRetry: () => setState(() => _streamKey++),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  }
                  final cars = snapshot.data ?? const <CarListingModel>[];
                  if (cars.isEmpty) {
                    return const EmptyStateView(
                      title: 'لا توجد مركبات في المخزون حالياً',
                      description: 'أضف أول مركبة من النموذج أعلاه ليتم إنشاؤها وتوليد ملصق QR الخاص بها.',
                    );
                  }

                  return Column(
                    children: cars.map((car) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runAlignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  car.title,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'السعر: ${car.price} ريال · الحالة: ${car.statusLabel}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.surface,
                                      foregroundColor: AppColors.textPrimary,
                                      side: const BorderSide(color: AppColors.borderStrong),
                                    ),
                                    onPressed: () => showCarQrStickerDialog(context, car),
                                    icon: const Icon(Icons.qr_code_2, size: 18),
                                    label: const Text('ملصق QR'),
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: car.status,
                                  items: const [
                                    DropdownMenuItem<String>(value: 'available', child: Text('متاحة')),
                                    DropdownMenuItem<String>(value: 'reserved', child: Text('محجوزة')),
                                    DropdownMenuItem<String>(value: 'sold', child: Text('مباعة')),
                                  ],
                                  onChanged: (next) async {
                                    if (next == null || next == car.status) return;
                                    try {
                                      await widget.repository.updateCarStatus(car.id, next);
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(SafeErrorMapper.toUserMessage(e))),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
