import 'dart:math';

class PricingRules {
  static const int inspectionTotal = 250;
  static const int inspectorShare = 200; // 80%
  static const int platformInspectionShare = 50; // 20%
  static const int defaultShippingEstimate = 650;

  static const _coords = {
    'riyadh': [24.7136, 46.6753],
    'الرياض': [24.7136, 46.6753],
    'eastern': [26.4207, 50.0888],
    'الدمام': [26.4207, 50.0888],
    'الخبر': [26.2172, 50.1971],
    'الظهران': [26.2361, 50.0393],
    'الأحساء': [25.3800, 49.5888],
    'الجبيل': [27.0112, 49.6583],
    'حفر الباطن': [28.4328, 45.9708],
    'makkah': [21.4858, 39.1925],
    'جدة': [21.4858, 39.1925],
    'مكة المكرمة': [21.3891, 39.8579],
    'الطائف': [21.2703, 40.4158],
    'madinah': [24.5247, 39.5692],
    'المدينة المنورة': [24.5247, 39.5692],
    'ينبع': [24.0232, 38.1900],
    'qassim': [26.3260, 43.9750],
    'بريدة (القصيم)': [26.3260, 43.9750],
    'asir': [18.2164, 42.5053],
    'أبها (عسير)': [18.2164, 42.5053],
    'خميس مشيط': [18.3060, 42.7297],
    'tabuk': [28.3838, 36.5550],
    'تبوك': [28.3838, 36.5550],
    'hail': [27.5114, 41.7208],
    'حائل': [27.5114, 41.7208],
    'jazan': [16.8892, 42.5511],
    'جازان': [16.8892, 42.5511],
    'najran': [17.4924, 44.1277],
    'نجران': [17.4924, 44.1277],
    'baha': [20.0129, 41.4677],
    'الباحة': [20.0129, 41.4677],
    'jouf': [29.9697, 40.2064],
    'سكاكا (الجوف)': [29.9697, 40.2064],
    'northern': [30.9753, 41.0381],
    'عرعر': [30.9753, 41.0381],
  };

  static int reservationFee(int carPrice) {
    if (carPrice <= 0) return 150;
    if (carPrice >= 250000) return 500;
    if (carPrice >= 100000) return 300;
    return 150;
  }

  static String tierLabel(int carPrice) {
    if (carPrice >= 250000) return 'الفئة الفاخرة (+250 ألف)';
    if (carPrice >= 100000) return 'الفئة المتوسطة (100 - 250 ألف)';
    return 'الفئة الاقتصادية (أقل من 100 ألف)';
  }

  static int estimateShippingFee(String fromRegionId, String toCityName) {
    final p1 = _coords[fromRegionId];
    final p2 = _coords[toCityName];
    if (p1 == null || p2 == null) return defaultShippingEstimate;
    final km = _haversineKm(p1[0], p1[1], p2[0], p2[1]) * 1.18;
    if (km < 60) return 200;
    final raw = (200 + (km * 0.90)).round();
    return ((raw + 25) ~/ 50) * 50;
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// حصة المنصة: 20% صافية
  static int platformTowShare(int shippingTotal) {
    if (shippingTotal <= 0) return 0;
    return (shippingTotal * 0.20).round();
  }

  /// حصة صاحب السطحة: 80% صافية
  static int driverTowShare(int shippingTotal) {
    if (shippingTotal <= 0) return 0;
    return shippingTotal - platformTowShare(shippingTotal);
  }

  // مكافأة إحالة معرض موثّق (بعد توثيق السجل والآيبان + رفع 5 سيارات)
  static const int showroomReferralReward = 20;

  // اشتراكات الفاحصين بعد فترة الإطلاق المجانية
  static const int inspectorIndividualMonthly = 149;
  static const int inspectorCenterMonthly = 299;

  // اشتراكات السطحات حسب النوع بعد فترة الإطلاق المجانية
  static const int towStandardMonthly = 99;
  static const int towVipHydraulicMonthly = 199;
  static const int towMultiCarrierMonthly = 349;

  static int inspectorMonthlyPrice(String tier) =>
      tier == 'center' ? inspectorCenterMonthly : inspectorIndividualMonthly;

  static int towMonthlyPrice(String truckType) {
    if (truckType == 'multi_carrier') return towMultiCarrierMonthly;
    if (truckType == 'vip_hydraulic') return towVipHydraulicMonthly;
    return towStandardMonthly;
  }
}
