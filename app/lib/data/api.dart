import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class NewAddress {
  final String label, line1, city, state, pincode;
  final String? line2;
  const NewAddress({required this.label, required this.line1, this.line2, required this.city, required this.state, required this.pincode});
  Map<String, dynamic> toJson() => {'label': label, 'line1': line1, if (line2 != null && line2!.isNotEmpty) 'line2': line2, 'city': city, 'state': state, 'pincode': pincode};
}

/// Everything the app needs from the Gowri backend (which fronts Zoho).
abstract class GowriApi {
  /// True for the built-in demo data source.
  bool get isDemo;

  String? get token;
  set token(String? t);

  Future<void> sendOtp(String phone);
  Future<Customer> verifyOtp(String phone, String code);
  Future<Customer> me();

  /// Saves name and email on the customer's Zoho contact (used for invoices).
  Future<Customer> updateProfile({required String name, String email = ''});

  Future<List<Product>> products();
  Future<List<Coupon>> coupons();

  Future<List<Address>> addresses();
  Future<Address> addAddress(NewAddress a);

  Future<List<String>> wishlist();
  Future<void> saveWishlist(List<String> skus);

  Future<PlaceOrderResult> placeOrder({required Map<String, int> items, String? couponCode, String? addressId, required PaymentMethod payment});
  Future<String> retryPayment(String salesOrderId);
  Future<List<Order>> orders();
  Future<Order> order(String salesOrderId);

  /// A short-lived URL for the order's GST invoice PDF.
  Future<String> invoiceLink(String salesOrderId);
  Future<({String returnId, int amount})> requestReturn(String salesOrderId, List<String> skus, String reason);
}
