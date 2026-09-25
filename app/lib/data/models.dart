// Mirrors backend/src/types.ts.

num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

class ProductSection {
  final String title;
  final String body;
  const ProductSection(this.title, this.body);
  factory ProductSection.fromJson(Map<String, dynamic> j) => ProductSection(j['title'] ?? '', j['body'] ?? '');
}

class Product {
  final String sku;
  final String name;
  final String size;
  final int mrp;
  final int price;
  final int gst;
  final int stock;
  final String category;
  final String concern;
  final String warehouse;
  final bool best;
  final bool rec;
  final String? imageUrl;
  final List<ProductSection> sections;

  const Product({
    required this.sku,
    required this.name,
    required this.size,
    required this.mrp,
    required this.price,
    required this.gst,
    required this.stock,
    required this.category,
    required this.concern,
    this.warehouse = 'Hyderabad',
    this.best = false,
    this.rec = false,
    this.imageUrl,
    this.sections = const [],
  });

  int get off => mrp == 0 ? 0 : ((1 - price / mrp) * 100).round();

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        sku: j['sku'],
        name: j['name'],
        size: j['size'] ?? '',
        mrp: _n(j['mrp']).round(),
        price: _n(j['price']).round(),
        gst: _n(j['gst']).round(),
        stock: _n(j['stock']).toInt(),
        category: j['category'] ?? '',
        concern: j['concern'] ?? '',
        warehouse: j['warehouse'] ?? 'Hyderabad',
        best: j['best'] == true,
        rec: j['rec'] == true,
        imageUrl: j['imageUrl'],
        sections: [for (final s in (j['sections'] as List? ?? const [])) ProductSection.fromJson(s)],
      );
}

class Coupon {
  final String code;
  final String value;
  final String desc;
  final int pct;
  final String? concern;
  final bool ship;
  final int minOrder;
  final bool firstOrderOnly;

  const Coupon({required this.code, required this.value, required this.desc, this.pct = 0, this.concern, this.ship = false, this.minOrder = 0, this.firstOrderOnly = false});

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        code: j['code'],
        value: j['value'] ?? '',
        desc: j['desc'] ?? '',
        pct: _n(j['pct']).toInt(),
        concern: j['concern'],
        ship: j['ship'] == true,
        minOrder: _n(j['minOrder']).toInt(),
        // The server enforces first-order rules; mirror it from the copy for instant feedback.
        firstOrderOnly: j['firstOrderOnly'] == true || '${j['desc']}'.toLowerCase().contains('first order'),
      );
}

class Address {
  final String id;
  final String label;
  final String line;
  final String? pincode;
  const Address({required this.id, required this.label, required this.line, this.pincode});
  factory Address.fromJson(Map<String, dynamic> j) => Address(id: '${j['id']}', label: j['label'] ?? '', line: j['line'] ?? '', pincode: j['pincode']);

  /// "Jubilee Hills 500033" for the Home header.
  String get short {
    final parts = line.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    // "…, Jubilee Hills, Hyderabad 500033": the area is the part before the city.
    final area = parts.length >= 2 ? parts[parts.length - 2] : (parts.isNotEmpty ? parts.first : '');
    return [area, pincode ?? RegExp(r'\b\d{6}\b').firstMatch(line)?.group(0) ?? ''].where((s) => s.isNotEmpty).join(' ');
  }
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String memberSince;
  const Customer({required this.id, required this.name, required this.phone, required this.memberSince});
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(id: j['id'], name: j['name'] ?? '', phone: j['phone'] ?? '', memberSince: '${j['memberSince'] ?? ''}');

  /// Zoho contacts created by the app are named "Gowri customer 1234" until the customer sets a name.
  bool get hasRealName => name.isNotEmpty && !name.startsWith('Gowri customer');
  String get firstName => hasRealName ? name.split(' ').first : '';
  String get initial => hasRealName ? name[0].toUpperCase() : 'G';
}

enum PaymentMethod {
  upi('UPI', 'GPay, PhonePe, Paytm'),
  card('Card', 'Visa, Mastercard, RuPay'),
  wallet('Wallet', 'Amazon Pay, Mobikwik'),
  netbanking('Net banking', 'All major banks'),
  cod('Cash on delivery', '₹30 handling');

  final String label;
  final String hint;
  const PaymentMethod(this.label, this.hint);
}

class CartLine {
  final Product product;
  final int qty;
  const CartLine(this.product, this.qty);
  int get lineTotal => product.price * qty;
}

class Totals {
  final List<CartLine> items;
  final int mrp, discount, coupon, afterDiscounts, shipping, codFee, total, gst;
  final String? couponCode;
  final String deliveryLabel;
  const Totals({
    required this.items,
    required this.mrp,
    required this.discount,
    required this.coupon,
    required this.afterDiscounts,
    required this.shipping,
    required this.codFee,
    required this.total,
    required this.gst,
    required this.couponCode,
    required this.deliveryLabel,
  });
}

enum StepStatus { done, current, pending }

class OrderStep {
  final String title;
  final String sub;
  final StepStatus state;
  const OrderStep(this.title, this.sub, this.state);
  factory OrderStep.fromJson(Map<String, dynamic> j) => OrderStep(j['title'], j['sub'], StepStatus.values.byName(j['state']));
}

class OrderItem {
  final String sku;
  final String name;
  final int qty;
  final int price;
  final int lineTotal;
  const OrderItem({required this.sku, required this.name, required this.qty, required this.price, required this.lineTotal});
  factory OrderItem.fromJson(Map<String, dynamic> j) =>
      OrderItem(sku: j['sku'], name: j['name'], qty: _n(j['qty']).toInt(), price: _n(j['price']).round(), lineTotal: _n(j['lineTotal']).round());
}

class Order {
  final String id;
  final String zohoSo;
  final String salesOrderId;
  final String date;
  final String status;
  final int stage;
  final List<OrderItem> items;
  final String payment;
  final int total;
  final String eta;
  final String courier;
  final List<OrderStep> steps;
  final bool invoiceAvailable;

  /// Live rider tracking link from Pidge, once a rider is assigned.
  final String? trackingUrl;

  const Order({
    required this.id,
    required this.zohoSo,
    required this.salesOrderId,
    required this.date,
    required this.status,
    required this.stage,
    required this.items,
    required this.payment,
    required this.total,
    required this.eta,
    required this.courier,
    required this.steps,
    this.invoiceAvailable = false,
    this.trackingUrl,
  });

  bool get awaitingPayment => status == 'Awaiting payment';
  bool get delivered => stage >= 4;
  String get summary => items.map((i) => i.name + (i.qty > 1 ? ' ×${i.qty}' : '')).join(', ');

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        zohoSo: j['zohoSo'],
        salesOrderId: j['salesOrderId'],
        date: j['date'],
        status: j['status'],
        stage: _n(j['stage']).toInt(),
        items: [for (final i in j['items'] as List) OrderItem.fromJson(i)],
        payment: j['payment'] ?? '—',
        total: _n(j['total']).round(),
        eta: j['eta'] ?? '',
        courier: j['courier'] ?? '',
        steps: [for (final s in j['steps'] as List) OrderStep.fromJson(s)],
        invoiceAvailable: j['invoiceAvailable'] == true,
        trackingUrl: j['trackingUrl'],
      );
}

class PlaceOrderResult {
  final Order order;
  final String? payUrl;
  const PlaceOrderResult(this.order, this.payUrl);
}
