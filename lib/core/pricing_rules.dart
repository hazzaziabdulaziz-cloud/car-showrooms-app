class PricingRules {
  static const int inspectionTotal = 250;
  static const int inspectorShare = 200; // 80%
  static const int platformInspectionShare = 50; // 20%

  static const int defaultShippingEstimate = 650;

  static int reservationFee(int carPrice) {
    if (carPrice >= 250000) return 500;
    if (carPrice >= 100000) return 300;
    return 150;
  }

  static String tierLabel(int carPrice) {
    if (carPrice >= 250000) return 'الفئة الفاخرة (+250 ألف)';
    if (carPrice >= 100000) return 'الفئة المتوسطة (100 - 250 ألف)';
    return 'الفئة الاقتصادية (أقل من 100 ألف)';
  }

  static int platformTowShare(int shippingTotal) {
    final pct = (shippingTotal * 0.10).round();
    return pct > 80 ? 80 : pct;
  }

  static int driverTowShare(int shippingTotal) {
    return shippingTotal - platformTowShare(shippingTotal);
  }
}
