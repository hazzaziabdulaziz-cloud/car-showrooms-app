import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_core.dart';

typedef TxResult = Map<String, dynamic>;

class RegionInfo {
  final String id;
  final String nameAr;
  final List<String> hubs;
  final double lat;
  final double lng;

  String get defaultHub => hubs.first;

  const RegionInfo({
    required this.id,
    required this.nameAr,
    required this.hubs,
    required this.lat,
    required this.lng,
  });
}

const List<RegionInfo> kSaudiRegions = [
  RegionInfo(id: 'riyadh', nameAr: 'الرياض', hubs: ['معارض القادسية', 'معارض الشفا (المروة)', 'طريق خريص (المنار والربوة)', 'الخرج'], lat: 24.7136, lng: 46.6753),
  RegionInfo(id: 'eastern', nameAr: 'المنطقة الشرقية', hubs: ['معارض الدمام (ضاحية الملك فهد)', 'الأحساء (المبرز والهفوف)', 'الخبر (الثقبة)', 'حفر الباطن', 'الجبيل', 'القطيف'], lat: 26.4207, lng: 50.0888),
  RegionInfo(id: 'makkah', nameAr: 'مكة المكرمة', hubs: ['معارض الجوهرة (جدة)', 'معارض عسفان (جدة)', 'مكة المكرمة', 'الطائف'], lat: 21.4858, lng: 39.1925),
  RegionInfo(id: 'madinah', nameAr: 'المدينة المنورة', hubs: ['معارض المدينة المنورة', 'ينبع'], lat: 24.5247, lng: 39.5692),
  RegionInfo(id: 'qassim', nameAr: 'القصيم', hubs: ['معارض بريدة', 'عنيزة', 'الرس'], lat: 26.3260, lng: 43.9750),
  RegionInfo(id: 'asir', nameAr: 'عسير', hubs: ['معارض خميس مشيط', 'أبها', 'بيشة'], lat: 18.2465, lng: 42.5117),
  RegionInfo(id: 'tabuk', nameAr: 'تبوك', hubs: ['معارض تبوك'], lat: 28.3835, lng: 36.5662),
  RegionInfo(id: 'hail', nameAr: 'حائل', hubs: ['معارض حائل'], lat: 27.5114, lng: 41.7208),
  RegionInfo(id: 'northern', nameAr: 'الحدود الشمالية', hubs: ['معارض عرعر', 'رفحاء'], lat: 30.9753, lng: 41.0381),
  RegionInfo(id: 'jazan', nameAr: 'جازان', hubs: ['معارض جازان', 'صبيا'], lat: 16.8894, lng: 42.5706),
  RegionInfo(id: 'najran', nameAr: 'نجران', hubs: ['معارض نجران'], lat: 17.4924, lng: 44.1277),
  RegionInfo(id: 'bahah', nameAr: 'الباحة', hubs: ['معارض الباحة', 'بلجرشي'], lat: 20.0129, lng: 41.4677),
  RegionInfo(id: 'jouf', nameAr: 'الجوف', hubs: ['معارض سكاكا', 'القريات'], lat: 29.9697, lng: 40.2064),
];

RegionInfo findRegion(String id) {
  return kSaudiRegions.firstWhere((r) => r.id == id, orElse: () => kSaudiRegions.first);
}

class ShowroomModel {
  final String id;
  final String commercialName;
  final String crNumber;
  final String regionId;
  final String cityHub;
  final String nationalAddress;
  final String ownerUid;
  final String contactPhone;
  final String bankName;
  final String iban;
  final String ibanCertUrl;
  final bool isVerified;
  final bool isPrimeSpot;
  final double rating;

  const ShowroomModel({
    required this.id,
    required this.commercialName,
    required this.crNumber,
    required this.regionId,
    required this.cityHub,
    required this.nationalAddress,
    required this.ownerUid,
    required this.contactPhone,
    required this.bankName,
    required this.iban,
    this.ibanCertUrl = '',
    required this.isVerified,
    required this.isPrimeSpot,
    required this.rating,
  });

  factory ShowroomModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ShowroomModel(
      id: doc.id,
      commercialName: (data['commercial_name'] ?? data['name'] ?? 'معرض معتمد').toString(),
      crNumber: (data['cr_number'] ?? '').toString(),
      regionId: (data['region_id'] ?? 'riyadh').toString(),
      cityHub: (data['city_hub'] ?? '').toString(),
      nationalAddress: (data['national_address'] ?? '').toString(),
      ownerUid: (data['owner_uid'] ?? '').toString(),
      contactPhone: (data['contact_phone'] ?? '').toString(),
      bankName: (data['bank_name'] ?? '').toString(),
      iban: (data['iban'] ?? '').toString(),
      ibanCertUrl: (data['iban_cert_url'] ?? '').toString(),
      isVerified: data['is_verified'] == true,
      isPrimeSpot: data['is_prime_spot'] == true,
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 4.8,
    );
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
  final bool hasBackhaulTow;
  final List<String> imageUrls;

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
    required this.hasBackhaulTow,
    this.imageUrls = const [],
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
      hasBackhaulTow: data['has_backhaul_tow'] == true,
      imageUrls: (data['image_urls'] is List) ? (data['image_urls'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [],
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

  String get qrPayload => 'https://car-showrooms-sa.web.app/c/$id';
}

class ShowroomRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<ShowroomModel?> watchMyShowroom(String uid) {
    return _firestore
        .collection('showrooms')
        .where('owner_uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : ShowroomModel.fromDoc(snap.docs.first));
  }

  Stream<List<ShowroomModel>> watchShowrooms() {
    return _firestore.collection('showrooms').snapshots().map((snap) {
      final now = DateTime.now();
      final active = snap.docs.where((doc) {
        final ts = doc.data()['subscription_expires_at'];
        if (ts is Timestamp) return ts.toDate().isAfter(now);
        return true;
      }).map(ShowroomModel.fromDoc).toList();
      active.sort((a, b) => (b.isPrimeSpot ? 1 : 0).compareTo(a.isPrimeSpot ? 1 : 0));
      return active;
    });
  }

  Stream<List<CarListingModel>> watchCars({int limit = 100}) {
    return _firestore
        .collection('cars')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => (doc.data()['status'] ?? 'available') == 'available')
            .map(CarListingModel.fromDoc)
            .toList());
  }

  Future<void> seedVirtualMallDemo() async {
    final existingShowrooms = await _firestore.collection('showrooms').limit(1).get();
    if (existingShowrooms.docs.isEmpty) {
      final batch = _firestore.batch();
      batch.set(_firestore.collection('showrooms').doc('sr_qadisiyah_01'), {
        'commercial_name': 'معرض الأفق للسيارات',
        'cr_number': '1010458921',
        'region_id': 'riyadh',
        'city_hub': 'معارض القادسية',
        'national_address': 'RAAA4521',
        'contact_phone': '0500001111',
        'is_verified': true,
        'is_prime_spot': true,
        'rating': 4.9,
        'created_at': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('showrooms').doc('sr_qadisiyah_02'), {
        'commercial_name': 'معرض النخبة الحديثة',
        'cr_number': '1010992831',
        'region_id': 'riyadh',
        'city_hub': 'معارض القادسية',
        'national_address': 'RAAA8812',
        'contact_phone': '0500002222',
        'is_verified': true,
        'is_prime_spot': false,
        'rating': 4.7,
        'created_at': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('showrooms').doc('sr_dammam_01'), {
        'commercial_name': 'معرض الساحل الشرقي',
        'cr_number': '2050123456',
        'region_id': 'eastern',
        'city_hub': 'معارض الدمام (ضاحية الملك فهد)',
        'national_address': 'DMMM3310',
        'contact_phone': '0500003333',
        'is_verified': true,
        'is_prime_spot': true,
        'rating': 4.8,
        'created_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    }

    final existingCars = await _firestore.collection('cars').limit(1).get();
    if (existingCars.docs.isEmpty) {
      final batch = _firestore.batch();
      final samples = [
        {
          'make': 'تويوتا',
          'model': 'كامري قراندي',
          'year': 2026,
          'price': 142000,
          'condition': 'new',
          'mileage': 0,
          'body_condition': 'أصفار وكالة',
          'spec_type': 'saudi',
          'region_id': 'riyadh',
          'city_hub': 'معارض القادسية',
          'showroom_id': 'sr_qadisiyah_01',
          'showroom_name': 'معرض الأفق للسيارات',
          'is_showroom_verified': true,
          'status': 'available',
          'has_backhaul_tow': true,
          'created_at': FieldValue.serverTimestamp(),
        },
        {
          'make': 'لكزس',
          'model': 'ES 350 CC',
          'year': 2025,
          'price': 238000,
          'condition': 'used',
          'mileage': 12500,
          'body_condition': 'بودي وكالة بالكامل',
          'spec_type': 'saudi',
          'region_id': 'riyadh',
          'city_hub': 'معارض القادسية',
          'showroom_id': 'sr_qadisiyah_01',
          'showroom_name': 'معرض الأفق للسيارات',
          'is_showroom_verified': true,
          'status': 'available',
          'has_backhaul_tow': false,
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
          'showroom_id': 'sr_dammam_01',
          'showroom_name': 'معرض الساحل الشرقي',
          'is_showroom_verified': true,
          'status': 'available',
          'has_backhaul_tow': true,
          'created_at': FieldValue.serverTimestamp(),
        },
      ];
      for (final item in samples) {
        batch.set(_firestore.collection('cars').doc(), item);
      }
      await batch.commit();
    }
  }

  Future<String> registerShowroom({
    required String commercialName,
    required String crNumber,
    required String regionId,
    required String cityHub,
    required String nationalAddress,
    required String contactPhone,
    required String bankName,
    required String iban,
    String ibanCertUrl = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('يجب تسجيل الدخول أولاً.');
    final docRef = await _firestore.collection('showrooms').add({
      'owner_uid': uid,
      'bank_name': SecurityGuard.sanitizeText(bankName, maxLength: 60),
      'iban': iban.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
      'iban_cert_url': ibanCertUrl,
      'commercial_name': SecurityGuard.sanitizeText(commercialName, maxLength: 90),
      'cr_number': SecurityGuard.sanitizeText(crNumber, maxLength: 10),
      'region_id': regionId,
      'city_hub': SecurityGuard.sanitizeText(cityHub, maxLength: 90),
      'national_address': SecurityGuard.sanitizeText(nationalAddress, maxLength: 12),
      'contact_phone': SecurityGuard.sanitizeText(contactPhone, maxLength: 15),
      'is_verified': false,
      'status': 'pending_review',
      'is_prime_spot': false,
      'rating': 5.0,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<String> registerTowDriver({
    required String driverName,
    required String phone,
    required String truckType,
    required String primaryRegionId,
    required bool acceptsBackhaul,
    required String bankName,
    required String iban,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('يجب تسجيل الدخول أولاً.');
    final docRef = await _firestore.collection('tow_drivers').add({
      'owner_uid': uid,
      'bank_name': SecurityGuard.sanitizeText(bankName, maxLength: 60),
      'iban': iban.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
      'driver_name': SecurityGuard.sanitizeText(driverName, maxLength: 80),
      'phone': SecurityGuard.sanitizeText(phone, maxLength: 15),
      'truck_type': truckType,
      'primary_region_id': primaryRegionId,
      'accepts_backhaul': acceptsBackhaul,
      'status': 'active',
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
    required bool hasBackhaulTow,
    List<String> imageUrls = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('يجب تسجيل الدخول أولاً.');
    final docRef = await _firestore.collection('cars').add({
      'owner_uid': uid,
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
      'has_backhaul_tow': hasBackhaulTow,
      'image_urls': imageUrls,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateCarStatus(String carId, String status) async {
    await _firestore.collection('cars').doc(carId).update({'status': status});
  }

  Future<void> deleteCar(String carId) async {
    await _firestore.collection('cars').doc(carId).delete();
  }

  Future<TxResult> createOrder({
    required String type,
    required String title,
    required CarListingModel car,
    required String buyerRegionId,
    required int baseAmount,
    required int platformCommission,
  }) async {
    final partnerShare = baseAmount - platformCommission;
    final otpCode = (1000 + Random().nextInt(9000)).toString();

    final docRef = await _firestore.collection('transactions').add({
      'type': type,
      'title': title,
      'car_id': car.id,
      'car_title': car.title,
      'showroom_id': car.showroomId,
      'buyer_region_id': buyerRegionId,
      'base_amount': baseAmount,
      'partner_share': partnerShare,
      'platform_commission': platformCommission,
      'delivery_otp': otpCode,
      'status': 'pending_confirmation',
      'created_at': FieldValue.serverTimestamp(),
    });

    return {
      'tx_id': docRef.id,
      'base_amount': baseAmount,
      'partner_share': partnerShare,
      'platform_commission': platformCommission,
      'delivery_otp': otpCode,
    };
  }
}
