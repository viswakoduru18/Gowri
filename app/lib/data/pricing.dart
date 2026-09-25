import 'models.dart';

// Same rules as backend/src/domain/pricing.ts. The app prices the bag locally
// for instant feedback; the backend re-prices from live Zoho data at checkout
// and that total is what the customer is charged.

const freeShippingThreshold = 499;
const shippingFee = 49;
const codFee = 30;

/// Returns a customer-facing reason the coupon can't be used, or null.
String? couponProblem(Coupon c, int sell, bool isFirstOrder) {
  if (c.minOrder > 0 && sell < c.minOrder) return '${c.code} needs a minimum order of ₹${c.minOrder}.';
  if (c.firstOrderOnly && !isFirstOrder) return '${c.code} is valid on your first order only.';
  return null;
}

Totals price(List<CartLine> lines, {Coupon? coupon, PaymentMethod? payment, bool isFirstOrder = true}) {
  final items = lines.where((l) => l.qty > 0).toList();
  final mrp = items.fold(0, (a, i) => a + i.product.mrp * i.qty);
  final sell = items.fold(0, (a, i) => a + i.lineTotal);
  var ship = sell >= freeShippingThreshold || sell == 0 ? 0 : shippingFee;
  var cp = 0;
  final valid = coupon != null && couponProblem(coupon, sell, isFirstOrder) == null ? coupon : null;
  if (valid != null) {
    if (valid.ship) {
      ship = 0;
    } else if (valid.concern != null) {
      cp = (items.where((i) => i.product.concern == valid.concern).fold(0, (a, i) => a + i.lineTotal) * valid.pct / 100).round();
    } else {
      cp = (sell * valid.pct / 100).round();
    }
  }
  final cod = payment == PaymentMethod.cod && items.isNotEmpty ? codFee : 0;
  final after = sell - cp;
  final gst = items.fold(0.0, (a, i) => a + i.lineTotal * (i.product.gst / (100 + i.product.gst))).round();
  final label = ship == 0 ? (cod > 0 ? 'Free + ₹$codFee COD' : 'Free') : '₹$ship${cod > 0 ? ' + ₹$codFee COD' : ''}';
  return Totals(
    items: items,
    mrp: mrp,
    discount: mrp - sell,
    coupon: cp,
    afterDiscounts: after,
    shipping: ship,
    codFee: cod,
    total: after + ship + cod,
    gst: gst,
    couponCode: valid?.code,
    deliveryLabel: label,
  );
}
