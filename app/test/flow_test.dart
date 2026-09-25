import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gowri/data/mock_api.dart';
import 'package:gowri/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Walks the design's main path on the demo data source:
// OTP login → Home → add a best seller → Bag → coupon → Checkout (COD) → Tracking → Orders.

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  // Startup touches real async (prefs, bundled fonts), so wait on the UI rather than a frame count.
  Future<void> waitFor(WidgetTester t, Finder f) async {
    for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
      await settle(t);
    }
  }

  testWidgets('login to placed order', (t) async {
    t.view.physicalSize = const Size(402 * 3, 874 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(GowriApp(api: MockGowriApi(latency: Duration.zero, packAfter: const Duration(milliseconds: 200))));
    await waitFor(t, find.text('Send code'));

    expect(find.text('gowri'), findsOneWidget);
    expect(find.text("Hi there, let's get you in"), findsOneWidget);
    await t.enterText(find.byType(TextField), '9876543210');
    await t.pump();
    await t.tap(find.text('Send code'));
    await settle(t);

    expect(find.text('Enter the 4-digit code'), findsOneWidget);
    expect(find.text('Demo: any 4 digits work'), findsOneWidget);
    for (final d in ['1', '2', '3', '4']) {
      await t.tap(find.text(d).last);
      await t.pump();
    }
    await waitFor(t, find.text('Shop by concern'));

    // Home, "Shop by concern" direction
    expect(find.text('Sleep better, wake lighter'), findsOneWidget);
    expect(find.text('Shop by concern'), findsOneWidget);
    expect(find.textContaining('Jubilee Hills 500033', findRichText: true), findsOneWidget);
    expect(find.text('Only 6 left'), findsOneWidget);

    // Add magnesium spray (first best seller) and ashwagandha
    await t.ensureVisible(find.byIcon(Icons.add_rounded).first);
    await t.pump();
    await t.tap(find.byIcon(Icons.add_rounded).first);
    await t.pump();
    expect(find.text('MyGlo Magnesium Body Spray added'), findsOneWidget);
    await t.ensureVisible(find.text('Ashwagandha Calm Capsules'));
    await t.pump();
    await t.tap(find.text('Ashwagandha Calm Capsules'));
    await settle(t);
    expect(find.text('Inclusive of 12% GST · SKU GW-ASH-60'), findsOneWidget);
    await t.tap(find.text('Add to bag'));
    await t.pump();
    expect(find.text('In bag · 1'), findsOneWidget);
    await t.tap(find.text('View bag'));
    await settle(t);

    // Bag totals and coupon
    expect(find.text('Your bag'), findsOneWidget);
    expect(find.text('₹1249'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'sleep20');
    await t.pump();
    await t.tap(find.text('Apply'));
    await t.pump();
    expect(find.text('SLEEP20 applied. Nice.'), findsOneWidget);
    expect(find.text('−₹200'), findsOneWidget);
    expect(find.text('₹799 ›'), findsOneWidget);

    await t.tap(find.text('Checkout'));
    await settle(t);
    expect(find.text('Pay ₹799 with UPI'), findsOneWidget);
    await t.tap(find.text('Cash on delivery'));
    await t.pump();
    expect(find.text('Place order · ₹829'), findsOneWidget);
    await t.tap(find.text('Place order · ₹829'));
    await settle(t);

    expect(find.text('Thank you, Ananya!'), findsOneWidget);
    expect(find.textContaining('Sales Order SO-00502 is created in Zoho'), findsOneWidget);
    expect(find.text('Order GW-10502'), findsOneWidget);

    // Poll advances the demo order to "Packed"
    await t.pump(const Duration(seconds: 2));
    await settle(t);
    expect(find.text('In progress'), findsOneWidget);

    await t.tap(find.byIcon(Icons.chevron_left_rounded));
    await settle(t);
    expect(find.text('My orders'), findsOneWidget);
    expect(find.text('GW-10502'), findsOneWidget);
    expect(find.text('Packed'), findsOneWidget);

    // Leave the widget tree so periodic timers stop.
    await t.pumpWidget(const SizedBox());
  });
}
