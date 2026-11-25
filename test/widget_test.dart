import 'package:flutter_test/flutter_test.dart';
import 'package:car_showrooms_app/core/iban_validator.dart';
import 'package:car_showrooms_app/core/pricing_rules.dart';

void main() {
  test('PricingRules tiered reservation fees & tow split', () {
    expect(PricingRules.reservationFee(80000), 150);
    expect(PricingRules.reservationFee(150000), 300);
    expect(PricingRules.reservationFee(300000), 500);
    expect(PricingRules.platformTowShare(650), 130);
    expect(PricingRules.driverTowShare(650), 520);
  });

  test('IbanValidator MOD-97 catches invalid Saudi IBAN', () {
    expect(IbanValidator.validateSaudiIban('SA0380000000608010167519'), isNull);
    expect(IbanValidator.validateSaudiIban('SA0000000000000000000000'), isNotNull);
  });
}
