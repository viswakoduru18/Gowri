import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gowri/data/api.dart';
import 'package:gowri/data/http_api.dart';
import 'package:gowri/data/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Parses the exact JSON shapes produced by backend/src (see backend/test/api.test.ts).

void main() {
  final requests = <http.Request>[];
  final api = HttpGowriApi('https://api.test/', client: MockClient((req) async {
    requests.add(req);
    final path = req.url.path;
    Map<String, dynamic> body;
    var status = 200;
    if (path == '/v1/auth/otp/verify') {
      body = {'token': 'jwt', 'customer': {'id': 'c1', 'contactId': 'c1', 'name': 'Gowri customer 3210', 'phone': '9876543210', 'memberSince': '2026'}};
    } else if (path == '/v1/catalog/products') {
      body = {
        'products': [
          {'sku': 'MG-MAG-200', 'name': 'Spray', 'size': '200 ml', 'mrp': 550, 'price': 440, 'gst': 18, 'stock': 327, 'category': 'Body', 'concern': 'Sleep & Stress', 'warehouse': 'Hyderabad', 'best': true, 'rec': false, 'imageUrl': null, 'sections': [{'title': 'What it does', 'body': 'x'}]},
        ],
      };
    } else if (path == '/v1/orders' && req.method == 'POST') {
      status = 201;
      body = {
        'order': {
          'id': 'GW-1', 'zohoSo': 'SO-00001', 'salesOrderId': 'so1', 'date': '25 Sep 2026', 'status': 'Awaiting payment', 'stage': 0,
          'items': [{'sku': 'MG-MAG-200', 'qty': 1, 'name': 'Spray', 'price': 440, 'lineTotal': 440}],
          'payment': 'UPI', 'total': 489, 'eta': 'Sun, 27 Sep', 'courier': 'Courier assigned at dispatch', 'invoiceAvailable': false,
          'steps': [{'title': 'Order confirmed', 'sub': 'Sales Order SO-00001 created in Zoho', 'state': 'current'}, {'title': 'Packed at warehouse', 'sub': 'Pending', 'state': 'pending'}],
        },
        'payUrl': 'https://api.test/pay/so1',
      };
    } else {
      status = 409;
      body = {'error': 'Only 6 of MyGlo Vitamin D3 Drops left.'};
    }
    return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});
  }));

  test('verifyOtp stores the session token and sends it afterwards', () async {
    final c = await api.verifyOtp('9876543210', '1234');
    expect(c.hasRealName, isFalse);
    expect(c.firstName, '');
    expect(api.token, 'jwt');
    await api.products();
    expect(requests.last.headers['authorization'], 'Bearer jwt');
  });

  test('products and orders parse', () async {
    final ps = await api.products();
    expect(ps.single.off, 20);
    expect(ps.single.sections.single.title, 'What it does');
    final r = await api.placeOrder(items: {'MG-MAG-200': 1}, payment: PaymentMethod.upi, addressId: 'a1');
    expect(r.payUrl, 'https://api.test/pay/so1');
    expect(r.order.awaitingPayment, isTrue);
    expect(r.order.steps.first.state, StepStatus.current);
    expect(jsonDecode(requests.last.body), {'items': [{'sku': 'MG-MAG-200', 'qty': 1}], 'couponCode': null, 'addressId': 'a1', 'payment': 'upi'});
  });

  test('server errors surface their message', () async {
    await expectLater(api.orders(), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Only 6 of MyGlo Vitamin D3 Drops left.').having((e) => e.status, 'status', 409)));
  });
}
