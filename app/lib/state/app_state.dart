import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../data/pricing.dart';

enum Screen { login, home, shop, product, cart, checkout, tracking, orders, wishlist, coupons, returns, profile, editProfile }

const tabScreens = {Screen.home, Screen.shop, Screen.wishlist, Screen.orders, Screen.profile};

const returnReasons = ['Damaged in transit', 'Wrong item', 'Not as described', 'Changed my mind'];

/// App-wide state. Navigation is a single screen + history stack, as in the
/// design prototype, so the floating tab bar and toast sit above every screen.
class AppState extends ChangeNotifier {
  final GowriApi api;
  final bool gridHomeDefault;
  final int lowStockThreshold;

  AppState(this.api, {this.gridHomeDefault = false, this.lowStockThreshold = 15}) : gridHome = gridHomeDefault;

  static const _tokenKey = 'gowri.token';

  // ── Navigation ──────────────────────────────────────────────────────
  Screen screen = Screen.login;
  final List<Screen> _history = [];
  bool booting = true;

  bool get showTabs => tabScreens.contains(screen);
  bool get canGoBack => screen != Screen.login && (_history.isNotEmpty || screen != Screen.home);

  void go(Screen s) {
    if (s == screen) return;
    _history.add(screen);
    if (_history.length > 8) _history.removeAt(0);
    screen = s;
    toast = null;
    _onScreenChanged();
    notifyListeners();
  }

  void back() {
    if (screen == Screen.editProfile && onboardingProfile) return skipProfile();
    screen = _history.isNotEmpty ? _history.removeLast() : Screen.home;
    toast = null;
    _onScreenChanged();
    notifyListeners();
  }

  void _resetTo(Screen s) {
    _history.clear();
    screen = s;
    _onScreenChanged();
  }

  // ── Session ─────────────────────────────────────────────────────────
  Customer? customer;
  String phone = '';
  String otp = '';
  bool otpStage = false;
  bool authBusy = false;
  String? authError;

  Future<void> boot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_tokenKey);
      if (saved != null && !api.isDemo) {
        api.token = saved;
        customer = await api.me();
        phone = customer!.phone;
        await _loadAfterLogin();
        _resetTo(Screen.home);
      }
    } catch (_) {
      api.token = null;
    }
    booting = false;
    notifyListeners();
    unawaited(_loadCatalog());
  }

  void setPhone(String v) {
    phone = v.replaceAll(RegExp(r'\D'), '');
    if (phone.length > 10) phone = phone.substring(0, 10);
    authError = null;
    notifyListeners();
  }

  bool get phoneValid => RegExp(r'^[6-9]\d{9}$').hasMatch(phone);

  Future<void> sendOtp() async {
    if (!phoneValid || authBusy) return;
    authBusy = true;
    authError = null;
    notifyListeners();
    try {
      await api.sendOtp(phone);
      otpStage = true;
      otp = '';
    } on ApiException catch (e) {
      authError = e.message;
    } finally {
      authBusy = false;
      notifyListeners();
    }
  }

  void backToPhone() {
    otpStage = false;
    otp = '';
    authError = null;
    notifyListeners();
  }

  void keypad(String k) {
    if (k.isEmpty || authBusy) return;
    authError = null;
    if (k == '⌫') {
      if (otp.isNotEmpty) otp = otp.substring(0, otp.length - 1);
    } else if (otp.length < 4) {
      otp += k;
      if (otp.length == 4) Future.delayed(const Duration(milliseconds: 350), _verifyOtp);
    }
    notifyListeners();
  }

  Future<void> _verifyOtp() async {
    authBusy = true;
    notifyListeners();
    try {
      customer = await api.verifyOtp(phone, otp);
      if (!api.isDemo) (await SharedPreferences.getInstance()).setString(_tokenKey, api.token!);
      await _loadAfterLogin();
      otpStage = false;
      otp = '';
      _resetTo(Screen.home);
      // First sign-in: ask for the name that goes on orders and GST invoices.
      if (!customer!.hasRealName) {
        onboardingProfile = true;
        go(Screen.editProfile);
      }
    } on ApiException catch (e) {
      authError = e.message;
      otp = '';
    } finally {
      authBusy = false;
      notifyListeners();
    }
  }

  // ── Profile ─────────────────────────────────────────────────────────
  bool onboardingProfile = false;
  bool profileBusy = false;
  String? profileError;

  void editProfile() {
    onboardingProfile = false;
    profileError = null;
    go(Screen.editProfile);
  }

  Future<bool> saveProfile(String name, String email) async {
    if (profileBusy) return false;
    final n = name.trim();
    final e = email.trim();
    if (n.length < 2) {
      profileError = 'Please enter your full name';
      notifyListeners();
      return false;
    }
    if (e.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      profileError = 'Enter a valid email, or leave it empty';
      notifyListeners();
      return false;
    }
    profileBusy = true;
    profileError = null;
    notifyListeners();
    try {
      customer = await api.updateProfile(name: n, email: e);
      final wasOnboarding = onboardingProfile;
      onboardingProfile = false;
      if (wasOnboarding) {
        _resetTo(Screen.home);
        showToast('Welcome to Gowri, ${customer!.firstName}!', bag: false);
      } else {
        back();
        showToast('Profile updated', bag: false);
      }
      return true;
    } on ApiException catch (err) {
      profileError = err.message;
      return false;
    } finally {
      profileBusy = false;
      notifyListeners();
    }
  }

  void skipProfile() {
    onboardingProfile = false;
    _resetTo(Screen.home);
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    (await SharedPreferences.getInstance()).remove(_tokenKey);
    customer = null;
    otpStage = false;
    otp = '';
    cart.clear();
    orders = [];
    _resetTo(Screen.login);
    notifyListeners();
  }

  // ── Catalog ─────────────────────────────────────────────────────────
  List<Product> products = [];
  List<Coupon> coupons = [];
  bool catalogLoading = true;
  String? catalogError;

  Future<void> _loadCatalog() async {
    try {
      final r = await Future.wait([api.products(), api.coupons()]);
      products = r[0] as List<Product>;
      coupons = r[1] as List<Coupon>;
      catalogError = null;
    } on ApiException catch (e) {
      catalogError = e.message;
    }
    catalogLoading = false;
    notifyListeners();
  }

  Future<void> refreshCatalog() => _loadCatalog();

  Product? bySku(String sku) => products.where((p) => p.sku == sku).firstOrNull;

  List<String> get categories => ['All', ...{for (final p in products) p.category}];
  List<({String name, int count})> get concerns {
    final names = <String>[];
    for (final p in products) {
      if (p.concern.isNotEmpty && !names.contains(p.concern)) names.add(p.concern);
    }
    const preferred = ['Sleep & Stress', 'Skin & Glow', 'Immunity', 'Digestion'];
    int rank(String n) => preferred.contains(n) ? preferred.indexOf(n) : 99;
    names.sort((a, b) => rank(a).compareTo(rank(b)));
    return [for (final n in names.take(4)) (name: n, count: products.where((p) => p.concern == n).length)];
  }

  // Until items are flagged in Zoho (cf_best_seller / cf_recommended), show in-stock items first.
  List<Product> get _inStockFirst => [...products.where((p) => p.stock > 0), ...products.where((p) => p.stock == 0)];
  List<Product> get bestSellers {
    final flagged = products.where((p) => p.best).toList();
    return flagged.isNotEmpty ? flagged : _inStockFirst.take(6).toList();
  }

  List<Product> get recommended {
    final flagged = products.where((p) => p.rec).toList();
    return flagged.isNotEmpty ? flagged : _inStockFirst.where((p) => p.stock > 0 && !bestSellers.contains(p)).take(3).toList();
  }

  ({String label, StockLevel level}) stockOf(Product p) {
    if (p.stock == 0) return (label: 'Out of stock', level: StockLevel.out);
    if (p.stock <= lowStockThreshold) return (label: 'Only ${p.stock} left', level: StockLevel.low);
    return (label: 'In stock', level: StockLevel.ok);
  }

  // ── Home / Shop ─────────────────────────────────────────────────────
  bool gridHome;
  String query = '';
  String cat = 'All';

  void toggleGridHome() {
    gridHome = !gridHome;
    notifyListeners();
  }

  void openShop({String category = 'All', String q = ''}) {
    cat = category;
    query = q;
    go(Screen.shop);
    notifyListeners();
  }

  void setCategory(String c) {
    cat = c;
    if (screen != Screen.shop) go(Screen.shop);
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  List<Product> get filtered {
    final q = query.trim().toLowerCase();
    return products
        .where((p) => (cat == 'All' || p.category == cat || p.concern == cat) &&
            (q.isEmpty || p.name.toLowerCase().contains(q) || p.concern.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)))
        .toList();
  }

  // ── Product ─────────────────────────────────────────────────────────
  String? sku;
  Product get product => bySku(sku ?? '') ?? products.first;

  void openProduct(String s) {
    sku = s;
    go(Screen.product);
  }

  // ── Wishlist ────────────────────────────────────────────────────────
  List<String> wish = [];
  bool isWished(String s) => wish.contains(s);
  List<Product> get wishItems => [for (final s in wish) ?bySku(s)];

  void toggleWish(String s) {
    wish = isWished(s) ? wish.where((x) => x != s).toList() : [...wish, s];
    notifyListeners();
    unawaited(api.saveWishlist(wish).catchError((_) {}));
  }

  // ── Toast ───────────────────────────────────────────────────────────
  String? toast;
  bool toastShowsBag = true;
  Timer? _toastTimer;

  void showToast(String msg, {bool bag = true}) {
    toast = msg;
    toastShowsBag = bag;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  // ── Cart ────────────────────────────────────────────────────────────
  final Map<String, int> cart = {};
  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  void addToCart(String s) {
    final p = bySku(s);
    if (p == null) return;
    if (p.stock == 0) return showToast("Out of stock — we'll notify you", bag: false);
    final q = cart[s] ?? 0;
    if (q >= p.stock) return showToast('Only ${p.stock} in stock');
    cart[s] = q + 1;
    showToast('${p.name} added');
  }

  void setQty(String s, int delta) {
    final q = (cart[s] ?? 0) + delta;
    if (q <= 0) {
      cart.remove(s);
    } else {
      cart[s] = q.clamp(1, bySku(s)?.stock ?? q);
    }
    notifyListeners();
  }

  void buyNow(String s) {
    final p = bySku(s);
    if (p == null) return;
    if (p.stock == 0) return showToast("Out of stock — we'll notify you", bag: false);
    cart.putIfAbsent(s, () => 1);
    go(Screen.checkout);
  }

  // ── Coupons ─────────────────────────────────────────────────────────
  String couponInput = '';
  Coupon? coupon;
  String couponMsg = '';
  bool couponOk = false;

  void setCouponInput(String v) {
    couponInput = v;
    notifyListeners();
  }

  bool get _firstOrder => orders.isEmpty;

  void applyCoupon([Coupon? picked]) {
    final c = picked ?? coupons.where((c) => c.code == couponInput.trim().toUpperCase()).firstOrNull;
    if (c == null) {
      coupon = null;
      couponMsg = "Hmm, that code isn't valid.";
      couponOk = false;
    } else {
      coupon = c;
      couponInput = c.code;
      final sell = cartLines.fold(0, (a, l) => a + l.lineTotal);
      final problem = couponProblem(c, sell, _firstOrder);
      couponMsg = problem ?? '${c.code} applied. Nice.';
      couponOk = problem == null;
    }
    notifyListeners();
  }

  void useCoupon(Coupon c) {
    applyCoupon(c);
    go(Screen.cart);
  }

  // ── Totals ──────────────────────────────────────────────────────────
  List<CartLine> get cartLines => [
        for (final e in cart.entries)
          if (bySku(e.key) != null) CartLine(bySku(e.key)!, e.value),
      ];
  Totals get totals => price(cartLines, coupon: coupon, payment: pay, isFirstOrder: _firstOrder);

  // ── Checkout ────────────────────────────────────────────────────────
  List<Address> addresses = [];
  int addr = 0;
  PaymentMethod pay = PaymentMethod.upi;
  bool placing = false;

  Address? get selectedAddress => addresses.isEmpty ? null : addresses[addr.clamp(0, addresses.length - 1)];

  void selectAddress(int i) {
    addr = i;
    notifyListeners();
  }

  void selectPayment(PaymentMethod m) {
    pay = m;
    notifyListeners();
  }

  Future<Address> addAddress(NewAddress a) async {
    final saved = await api.addAddress(a);
    addresses = [...addresses, saved];
    addr = addresses.length - 1;
    notifyListeners();
    return saved;
  }

  String get payLabel => pay == PaymentMethod.cod ? 'Place order · ₹${totals.total}' : 'Pay ₹${totals.total} with ${pay.label}';

  /// Creates the Sales Order in Zoho. Returns the payment page URL for prepaid
  /// orders (the caller opens it), or null when the order is already confirmed.
  Future<String?> placeOrder() async {
    if (cart.isEmpty || placing) return null;
    if (selectedAddress == null) {
      showToast('Add a delivery address first', bag: false);
      return null;
    }
    placing = true;
    notifyListeners();
    try {
      final r = await api.placeOrder(items: Map.of(cart), couponCode: totals.couponCode, addressId: selectedAddress!.id, payment: pay);
      cart.clear();
      coupon = null;
      couponInput = '';
      couponMsg = '';
      order = r.order;
      orders = [r.order, ...orders.where((o) => o.salesOrderId != r.order.salesOrderId)];
      if (r.payUrl == null) _showPlaced();
      unawaited(_loadCatalog()); // stock just changed
      return r.payUrl;
    } on ApiException catch (e) {
      showToast(e.message, bag: false);
      if (e.status == 409) unawaited(_loadCatalog());
      return null;
    } finally {
      placing = false;
      notifyListeners();
    }
  }

  /// Called after the payment WebView closes.
  Future<void> paymentFinished(bool success) async {
    if (order == null) return;
    try {
      order = await api.order(order!.salesOrderId);
    } on ApiException catch (_) {}
    if (success && !(order?.awaitingPayment ?? true)) {
      _showPlaced();
    } else {
      justPlaced = false;
      _resetTo(Screen.tracking);
      showToast(success ? 'Confirming your payment…' : 'Payment not completed. You can retry below.', bag: false);
    }
    unawaited(loadOrders());
    notifyListeners();
  }

  Future<String?> retryPayment() async {
    if (order == null) return null;
    try {
      return await api.retryPayment(order!.salesOrderId);
    } on ApiException catch (e) {
      showToast(e.message, bag: false);
      return null;
    }
  }

  void _showPlaced() {
    justPlaced = true;
    _resetTo(Screen.tracking);
  }

  // ── Orders & tracking ───────────────────────────────────────────────
  List<Order> orders = [];
  Order? order;
  bool justPlaced = false;
  Timer? _poll;

  Future<void> loadOrders() async {
    try {
      orders = await api.orders();
      notifyListeners();
    } on ApiException catch (_) {}
  }

  void openOrder(Order o) {
    order = o;
    justPlaced = false;
    go(Screen.tracking);
  }

  void goOrders() {
    justPlaced = false;
    go(Screen.orders);
  }

  void reorder() {
    final o = order;
    if (o == null) return;
    cart.clear();
    for (final i in o.items) {
      final p = bySku(i.sku);
      if (p != null && p.stock > 0) cart[i.sku] = i.qty.clamp(1, p.stock);
    }
    go(Screen.cart);
  }

  Future<String?> invoiceLink() async {
    if (order == null) return null;
    if (!order!.invoiceAvailable) {
      showToast('Your GST invoice is ready once the order ships.', bag: false);
      return null;
    }
    try {
      return await api.invoiceLink(order!.salesOrderId);
    } on ApiException catch (e) {
      showToast(e.message, bag: false);
      return null;
    }
  }

  void _onScreenChanged() {
    _poll?.cancel();
    if (screen == Screen.tracking && order != null && !order!.delivered) {
      // Live status from Zoho packages/shipments; demo mode advances quickly.
      _poll = Timer.periodic(Duration(seconds: api.isDemo ? 1 : 20), (_) async {
        try {
          final fresh = await api.order(order!.salesOrderId);
          if (fresh.stage != order!.stage || fresh.status != order!.status) {
            order = fresh;
            orders = [for (final o in orders) o.salesOrderId == fresh.salesOrderId ? fresh : o];
            notifyListeners();
          }
        } on ApiException catch (_) {}
      });
    }
    if (screen == Screen.orders) unawaited(loadOrders());
  }

  // ── Returns ─────────────────────────────────────────────────────────
  Set<String> retSel = {};
  String? retReason;
  bool retDone = false;
  bool retBusy = false;
  int retAmount = 0;

  void openReturns() {
    retSel = {};
    retReason = null;
    retDone = false;
    go(Screen.returns);
  }

  void toggleReturnItem(String s) {
    retSel = retSel.contains(s) ? (Set.of(retSel)..remove(s)) : {...retSel, s};
    notifyListeners();
  }

  void setReturnReason(String r) {
    retReason = r;
    notifyListeners();
  }

  int get returnSelectionTotal => (order?.items ?? []).where((i) => retSel.contains(i.sku)).fold(0, (a, i) => a + i.lineTotal);
  bool get canSubmitReturn => returnSelectionTotal > 0 && retReason != null && !retBusy;

  Future<void> submitReturn() async {
    if (!canSubmitReturn) return;
    retBusy = true;
    notifyListeners();
    try {
      final r = await api.requestReturn(order!.salesOrderId, retSel.toList(), retReason!);
      retAmount = r.amount;
      retDone = true;
    } on ApiException catch (e) {
      showToast(e.message, bag: false);
    } finally {
      retBusy = false;
      notifyListeners();
    }
  }

  // ── Loading after sign-in ───────────────────────────────────────────
  Future<void> _loadAfterLogin() async {
    final r = await Future.wait([api.addresses(), api.wishlist(), api.orders()]);
    addresses = r[0] as List<Address>;
    wish = r[1] as List<String>;
    orders = r[2] as List<Order>;
    addr = 0;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }
}

enum StockLevel { ok, low, out }
