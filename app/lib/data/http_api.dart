import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';
import 'models.dart';

/// Talks to the Gowri backend (backend/), which holds the Zoho credentials.
class HttpGowriApi implements GowriApi {
  final String baseUrl;
  final http.Client _http;
  @override
  String? token;

  HttpGowriApi(String baseUrl, {http.Client? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
        _http = client ?? http.Client();

  @override
  bool get isDemo => false;

  Future<Map<String, dynamic>> _call(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 25)));
    } catch (_) {
      throw const ApiException("You're offline or our server is unreachable. Check your connection.");
    }
    final json = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw ApiException(json['error'] ?? 'Something went wrong.', res.statusCode);
    return json;
  }

  @override
  Future<void> sendOtp(String phone) => _call('POST', '/v1/auth/otp/send', {'phone': phone});

  @override
  Future<Customer> verifyOtp(String phone, String code) async {
    final j = await _call('POST', '/v1/auth/otp/verify', {'phone': phone, 'code': code});
    token = j['token'];
    return Customer.fromJson(j['customer']);
  }

  @override
  Future<Customer> me() async => Customer.fromJson((await _call('GET', '/v1/me'))['customer']);

  @override
  Future<List<Product>> products() async => [for (final p in (await _call('GET', '/v1/catalog/products'))['products']) Product.fromJson(p)];

  @override
  Future<List<Coupon>> coupons() async => [for (final c in (await _call('GET', '/v1/coupons'))['coupons']) Coupon.fromJson(c)];

  @override
  Future<List<Address>> addresses() async => [for (final a in (await _call('GET', '/v1/me/addresses'))['addresses']) Address.fromJson(a)];

  @override
  Future<Address> addAddress(NewAddress a) async => Address.fromJson((await _call('POST', '/v1/me/addresses', a.toJson()))['address']);

  @override
  Future<List<String>> wishlist() async => List<String>.from((await _call('GET', '/v1/me/wishlist'))['skus']);

  @override
  Future<void> saveWishlist(List<String> skus) => _call('PUT', '/v1/me/wishlist', {'skus': skus});

  @override
  Future<PlaceOrderResult> placeOrder({required Map<String, int> items, String? couponCode, String? addressId, required PaymentMethod payment}) async {
    final j = await _call('POST', '/v1/orders', {
      'items': [for (final e in items.entries) {'sku': e.key, 'qty': e.value}],
      'couponCode': couponCode,
      'addressId': addressId,
      'payment': payment.name,
    });
    return PlaceOrderResult(Order.fromJson(j['order']), j['payUrl']);
  }

  @override
  Future<String> retryPayment(String salesOrderId) async => (await _call('POST', '/v1/orders/$salesOrderId/pay', {}))['payUrl'];

  @override
  Future<List<Order>> orders() async => [for (final o in (await _call('GET', '/v1/orders'))['orders']) Order.fromJson(o)];

  @override
  Future<Order> order(String salesOrderId) async => Order.fromJson((await _call('GET', '/v1/orders/$salesOrderId'))['order']);

  @override
  Future<String> invoiceLink(String salesOrderId) async => (await _call('POST', '/v1/orders/$salesOrderId/invoice-link', {}))['url'];

  @override
  Future<({String returnId, int amount})> requestReturn(String salesOrderId, List<String> skus, String reason) async {
    final j = await _call('POST', '/v1/orders/$salesOrderId/returns', {'skus': skus, 'reason': reason});
    return (returnId: j['returnId'] as String, amount: (j['amount'] as num).round());
  }
}
