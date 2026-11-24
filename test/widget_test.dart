import 'package:flutter_test/flutter_test.dart';
import 'package:car_showrooms_app/data/showroom_repository.dart';

void main() {
  test('PricingCalculator computes service fee correctly', () {
    expect(PricingCalculator.serviceFeeFor(100), 5);
  });
}
