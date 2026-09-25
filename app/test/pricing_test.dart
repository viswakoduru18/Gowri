import 'package:flutter_test/flutter_test.dart';
import 'package:gowri/data/mock_api.dart';
import 'package:gowri/data/models.dart';
import 'package:gowri/data/pricing.dart';

// Same cases as backend/test/unit.test.ts so app and server agree on the bag total.

Product p(String sku) => demoProducts.firstWhere((x) => x.sku == sku);
Coupon c(String code) => demoCoupons.firstWhere((x) => x.code == code);

void main() {
  test('MRP, discount, free delivery at ₹499, GST extracted', () {
    final t = price([CartLine(p('MG-MAG-200'), 1), CartLine(p('GW-ASH-60'), 1)]);
    expect(t.mrp, 1249);
    expect(t.discount, 250);
    expect(t.total, 999);
    expect(t.deliveryLabel, 'Free');
    expect(t.gst, (440 * 18 / 118 + 559 * 12 / 112).round());
  });

  test('₹49 delivery below ₹499 and ₹30 COD fee', () {
    final t = price([CartLine(p('GW-HAIR-100'), 1)], payment: PaymentMethod.cod);
    expect(t.deliveryLabel, '₹49 + ₹30 COD');
    expect(t.total, 339 + 49 + 30);
  });

  test('SLEEP20 discounts only Sleep & Stress lines; FREESHIP waives delivery', () {
    expect(price([CartLine(p('MG-MAG-200'), 1), CartLine(p('GW-HAIR-100'), 1)], coupon: c('SLEEP20')).coupon, 88);
    expect(price([CartLine(p('GW-HAIR-100'), 1)], coupon: c('FREESHIP')).total, 339);
  });

  test('coupon rules: minimum order and first order only', () {
    expect(price([CartLine(p('GW-HAIR-100'), 1)], coupon: c('SLEEP20')).couponCode, isNull);
    expect(price([CartLine(p('GW-HAIR-100'), 2)], coupon: c('GLOW10'), isFirstOrder: false).coupon, 0);
    expect(price([CartLine(p('GW-HAIR-100'), 2)], coupon: c('GLOW10')).coupon, 68);
  });

  test('stock badge thresholds via off%', () {
    expect(p('MG-MAG-200').off, 20);
  });
}
