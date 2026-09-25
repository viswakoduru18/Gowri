import 'api.dart';
import 'models.dart';
import 'pricing.dart';

// Demo data source: the design's catalog and order history, fully offline.
// Used when the app is built without API_BASE_URL (design reviews, store
// screenshots). Any 4-digit OTP works and prepaid orders are treated as paid.

const _sections = {
  'MG-MAG-200': [
    ProductSection('What it does', 'Transdermal magnesium chloride that relaxes tired muscles and helps you wind down before bed.'),
    ProductSection('How to use', 'Spray 5–8 times on arms, legs or feet after a shower. Massage in. A light tingle is normal for the first week.'),
    ProductSection('Ingredients', 'Magnesium chloride (Zechstein), purified water, lavender oil.'),
    ProductSection('Good to know', 'Avoid broken skin. Not for children under 12. Store below 30°C.'),
  ],
  'MG-D3-30': [
    ProductSection('What it does', '600 IU per drop of plant-based D3 for bones, mood and immunity.'),
    ProductSection('How to use', 'One drop daily on the tongue or in food, with a meal.'),
    ProductSection('Ingredients', 'Vitamin D3 (lichen), MCT oil.'),
    ProductSection('Good to know', 'Consult your doctor if pregnant or on medication.'),
  ],
  'GW-ASH-60': [
    ProductSection('What it does', 'KSM-66 ashwagandha, 600 mg a day, to steady stress and support restful sleep.'),
    ProductSection('How to use', 'One capsule after breakfast, one after dinner.'),
    ProductSection('Ingredients', 'Ashwagandha root extract, vegetarian capsule.'),
    ProductSection('Good to know', 'Not recommended during pregnancy.'),
  ],
  'GW-GLW-50': [
    ProductSection('What it does', '10% stabilised vitamin C with hyaluronic acid for brighter, even-toned skin.'),
    ProductSection('How to use', '3–4 drops on clean skin every morning. Follow with SPF.'),
    ProductSection('Ingredients', 'Ethyl ascorbic acid, sodium hyaluronate, niacinamide.'),
    ProductSection('Good to know', 'Patch test first. Keep away from sunlight.'),
  ],
  'GW-PRO-30': [
    ProductSection('What it does', '10 billion CFU across 6 strains to settle bloating and support regular digestion.'),
    ProductSection('How to use', 'One sachet in water before breakfast.'),
    ProductSection('Ingredients', 'L. rhamnosus, B. lactis, FOS prebiotic fibre.'),
    ProductSection('Good to know', 'Store in a cool, dry place.'),
  ],
  'GW-HAIR-100': [
    ProductSection('What it does', 'Cold-pressed bhringraj and amla oil to reduce fall and nourish the scalp.'),
    ProductSection('How to use', 'Warm slightly, massage into scalp, leave 1 hour, wash.'),
    ProductSection('Ingredients', 'Bhringraj, amla, coconut oil, curry leaf.'),
    ProductSection('Good to know', 'For external use only.'),
  ],
  'GW-SLP-120': [
    ProductSection('What it does', 'Chamomile, brahmi and lemongrass to ease you into sleep without grogginess.'),
    ProductSection('How to use', 'Steep one bag for 5 minutes, 30 minutes before bed.'),
    ProductSection('Ingredients', 'Chamomile, brahmi, lemongrass, tulsi.'),
    ProductSection('Good to know', 'Caffeine free.'),
  ],
  'GW-SPF-50': [
    ProductSection('What it does', 'Zinc-oxide broad spectrum sunscreen, no white cast, non-greasy.'),
    ProductSection('How to use', 'Apply generously 15 minutes before sun. Reapply every 2 hours.'),
    ProductSection('Ingredients', 'Zinc oxide 18%, squalane, vitamin E.'),
    ProductSection('Good to know', 'Reef safe. Fragrance free.'),
  ],
};

final demoProducts = <Product>[
  Product(sku: 'MG-MAG-200', name: 'MyGlo Magnesium Body Spray', size: '200 ml', mrp: 550, price: 440, gst: 18, stock: 327, category: 'Body', concern: 'Sleep & Stress', best: true, sections: _sections['MG-MAG-200']!),
  Product(sku: 'MG-D3-30', name: 'MyGlo Vitamin D3 Drops', size: '30 ml', mrp: 450, price: 399, gst: 18, stock: 6, category: 'Vitamins', concern: 'Immunity', best: true, rec: true, sections: _sections['MG-D3-30']!),
  Product(sku: 'GW-ASH-60', name: 'Ashwagandha Calm Capsules', size: '60 capsules', mrp: 699, price: 559, gst: 12, stock: 142, category: 'Herbal', concern: 'Sleep & Stress', best: true, sections: _sections['GW-ASH-60']!),
  Product(sku: 'GW-GLW-50', name: 'Glow Vitamin C Face Serum', size: '50 ml', mrp: 899, price: 719, gst: 18, stock: 0, category: 'Skin', concern: 'Skin & Glow', best: true, sections: _sections['GW-GLW-50']!),
  Product(sku: 'GW-PRO-30', name: 'Daily Probiotic Sachets', size: '30 sachets', mrp: 1299, price: 1039, gst: 12, stock: 88, category: 'Gut', concern: 'Digestion', rec: true, sections: _sections['GW-PRO-30']!),
  Product(sku: 'GW-HAIR-100', name: 'Bhringraj Hair Oil', size: '100 ml', mrp: 399, price: 339, gst: 18, stock: 210, category: 'Hair', concern: 'Hair & Scalp', sections: _sections['GW-HAIR-100']!),
  Product(sku: 'GW-SLP-120', name: 'Sleep Ritual Herbal Tea', size: '20 bags', mrp: 349, price: 279, gst: 5, stock: 14, category: 'Herbal', concern: 'Sleep & Stress', sections: _sections['GW-SLP-120']!),
  Product(sku: 'GW-SPF-50', name: 'Mineral Sunscreen SPF 50', size: '50 g', mrp: 649, price: 519, gst: 18, stock: 73, category: 'Skin', concern: 'Skin & Glow', sections: _sections['GW-SPF-50']!),
];

const demoCoupons = [
  Coupon(code: 'SLEEP20', value: '20% OFF', desc: '20% off Sleep & Stress products. Min. order ₹499.', pct: 20, concern: 'Sleep & Stress', minOrder: 499),
  Coupon(code: 'GLOW10', value: '10% OFF', desc: '10% off your whole bag. Valid on first order.', pct: 10, firstOrderOnly: true),
  Coupon(code: 'FREESHIP', value: 'FREE', desc: 'Free delivery on any order.', ship: true),
];

const _stepTitles = ['Order confirmed', 'Packed at warehouse', 'Shipped', 'Out for delivery', 'Delivered'];

class _DemoOrder {
  final String id, so, date, payment;
  final Map<String, int> items;
  int stage;
  final int? total;
  _DemoOrder(this.id, this.so, this.date, this.items, this.payment, this.stage, [this.total]);
}

class MockGowriApi implements GowriApi {
  @override
  String? token;
  final Duration latency;
  final Duration packAfter;

  MockGowriApi({this.latency = const Duration(milliseconds: 250), this.packAfter = const Duration(seconds: 3)});

  @override
  bool get isDemo => true;

  Customer _customer = const Customer(id: 'demo', name: 'Ananya Rao', phone: '', memberSince: '2024');
  final _addresses = <Address>[
    const Address(id: 'a1', label: 'Home', line: 'Plot 42, Road No. 10, Jubilee Hills, Hyderabad 500033', pincode: '500033'),
    const Address(id: 'a2', label: 'Office', line: 'Gowri Life Sciences, HITEC City, Hyderabad 500081', pincode: '500081'),
  ];
  var _wish = <String>['GW-GLW-50'];
  final _orders = <_DemoOrder>[
    _DemoOrder('GW-10432', 'SO-00432', '12 Sep 2026', {'GW-ASH-60': 1, 'GW-SLP-120': 2}, 'UPI', 4),
    _DemoOrder('GW-10311', 'SO-00311', '28 Aug 2026', {'MG-MAG-200': 1}, 'Card', 4),
  ];

  Future<T> _later<T>(T Function() f) => Future.delayed(latency, f);
  Product _p(String sku) => demoProducts.firstWhere((p) => p.sku == sku);

  Order _toOrder(_DemoOrder o) {
    final items = [for (final e in o.items.entries) OrderItem(sku: e.key, name: _p(e.key).name, qty: e.value, price: _p(e.key).price, lineTotal: _p(e.key).price * e.value)];
    final delivered = o.stage >= 4;
    return Order(
      id: o.id,
      zohoSo: o.so,
      salesOrderId: o.id,
      date: o.date,
      status: const ['Confirmed', 'Packed', 'Shipped', 'Out for delivery', 'Delivered'][o.stage],
      stage: o.stage,
      items: items,
      payment: o.payment,
      total: o.total ?? items.fold(0, (a, i) => a + i.lineTotal),
      eta: delivered ? 'delivered ${o.date}' : 'Sun, 27 Sep',
      courier: delivered ? 'Pidge' : (o.stage >= 1 ? 'Pidge · Rider Ravi · 90000 00001' : 'Pidge · rider being assigned'),
      invoiceAvailable: delivered,
      steps: [
        for (var i = 0; i < _stepTitles.length; i++)
          OrderStep(
            _stepTitles[i],
            i < o.stage ? 'Done' : (i == o.stage ? (i == 0 ? 'Sales Order ${o.so} created in Zoho' : 'In progress') : 'Pending'),
            i < o.stage ? StepStatus.done : (i == o.stage ? StepStatus.current : StepStatus.pending),
          ),
      ],
    );
  }

  @override
  Future<void> sendOtp(String phone) => _later(() {});

  @override
  Future<Customer> verifyOtp(String phone, String code) => _later(() {
        token = 'demo';
        return _customer = Customer(id: 'demo', name: _customer.name, phone: phone, memberSince: '2024');
      });

  @override
  Future<Customer> me() => _later(() => _customer);

  @override
  Future<List<Product>> products() => _later(() => demoProducts);

  @override
  Future<List<Coupon>> coupons() => _later(() => demoCoupons);

  @override
  Future<List<Address>> addresses() => _later(() => List.of(_addresses));

  @override
  Future<Address> addAddress(NewAddress a) => _later(() {
        final addr = Address(id: 'a${_addresses.length + 1}', label: a.label, line: [a.line1, a.line2, a.city, '${a.state} ${a.pincode}'].where((s) => s != null && s.isNotEmpty).join(', '), pincode: a.pincode);
        _addresses.add(addr);
        return addr;
      });

  @override
  Future<List<String>> wishlist() => _later(() => List.of(_wish));

  @override
  Future<void> saveWishlist(List<String> skus) async => _wish = List.of(skus);

  @override
  Future<PlaceOrderResult> placeOrder({required Map<String, int> items, String? couponCode, String? addressId, required PaymentMethod payment}) => _later(() {
        for (final e in items.entries) {
          final p = _p(e.key);
          if (p.stock < e.value) throw ApiException(p.stock == 0 ? '${p.name} just sold out.' : 'Only ${p.stock} of ${p.name} left.', 409);
        }
        final coupon = demoCoupons.where((c) => c.code == couponCode).firstOrNull;
        final t = price([for (final e in items.entries) CartLine(_p(e.key), e.value)], coupon: coupon, payment: payment, isFirstOrder: _orders.isEmpty);
        final n = 10500 + _orders.length;
        final o = _DemoOrder('GW-$n', 'SO-00${n - 10000}', '25 Sep 2026', Map.of(items), payment.label, 0, t.total);
        _orders.insert(0, o);
        Future.delayed(packAfter, () => o.stage = o.stage < 1 ? 1 : o.stage);
        return PlaceOrderResult(_toOrder(o), null);
      });

  @override
  Future<String> retryPayment(String salesOrderId) async => throw const ApiException('Not needed in demo mode');

  @override
  Future<List<Order>> orders() => _later(() => [for (final o in _orders) _toOrder(o)]);

  @override
  Future<Order> order(String salesOrderId) => _later(() => _toOrder(_orders.firstWhere((o) => o.id == salesOrderId)));

  @override
  Future<String> invoiceLink(String salesOrderId) async => throw const ApiException('GST invoices open from Zoho Books in the live app.');

  @override
  Future<({String returnId, int amount})> requestReturn(String salesOrderId, List<String> skus, String reason) => _later(() {
        final o = _orders.firstWhere((o) => o.id == salesOrderId);
        return (returnId: 'RMA-1', amount: skus.fold(0, (a, s) => a + _p(s).price * (o.items[s] ?? 0)));
      });
}
