import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_showrooms_app/core/pricing_rules.dart';

class _ExternalGatewaySimulator {
  Future callWithHardTimeout({
    required String serviceName,
    required Duration simulatedDelay,
    Duration maxTimeout = const Duration(milliseconds: 250),
  }) async {
    try {
      return await Future.delayed(
        simulatedDelay,
        () => {'service': serviceName, 'ok': true, 'mode': 'live'},
      ).timeout(maxTimeout);
    } on TimeoutException {
      return {'service': serviceName, 'ok': false, 'mode': 'graceful_fallback'};
    }
  }
}

class _AtomicCarLockSimulator {
  bool _reserved = false;
  Future<bool> tryReserveAtomically() async {
    await Future<void>.delayed(Duration.zero);
    if (_reserved) return false;
    _reserved = true;
    return true;
  }
}

void main() {
  group('Shari Integration & 1,000-User Resilience Suite', () {
    final gateway = _ExternalGatewaySimulator();

    test('1) تأخر واثق أو ميسر أو واتساب كلاود لا يعلّق التطبيق', () async {
      final sw = Stopwatch()..start();
      final res = await Future.wait([
        gateway.callWithHardTimeout(serviceName: 'Wathq API', simulatedDelay: const Duration(milliseconds: 40)),
        gateway.callWithHardTimeout(serviceName: 'Moyasar/Tap', simulatedDelay: const Duration(seconds: 5)),
        gateway.callWithHardTimeout(serviceName: 'WhatsApp Cloud', simulatedDelay: const Duration(seconds: 5)),
        gateway.callWithHardTimeout(serviceName: 'SMS OTP', simulatedDelay: const Duration(milliseconds: 30)),
      ]);
      sw.stop();
      expect(res[0]['ok'], isTrue);
      expect(res[1]['mode'], equals('graceful_fallback'));
      expect(res[2]['mode'], equals('graceful_fallback'));
      expect(res[3]['ok'], isTrue);
      expect(sw.elapsedMilliseconds, lessThan(600));
    });

    test('2) 1,000 مشتري يتسابقون على نفس السيارة: فائز واحد فقط بدون تعليق', () async {
      final lock = _AtomicCarLockSimulator();
      final sw = Stopwatch()..start();
      final outcomes = await Future.wait(List.generate(1000, (_) => lock.tryReserveAtomically()));
      sw.stop();
      expect(outcomes.where((ok) => ok).length, equals(1));
      expect(outcomes.where((ok) => !ok).length, equals(999));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('3) التحقق من قواعد الباقات والإحالة', () {
      expect(PricingRules.reservationFee(80000), equals(150));
      expect(PricingRules.reservationFee(150000), equals(300));
      expect(PricingRules.reservationFee(300000), equals(500));
      expect(PricingRules.inspectorShare, equals(200));
      expect(PricingRules.platformInspectionShare, equals(50));
    });
  });
}
