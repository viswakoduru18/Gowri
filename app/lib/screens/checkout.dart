import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/address_sheet.dart';
import '../widgets/common.dart';
import 'payment_webview.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  Future<void> _place(BuildContext context) async {
    final s = context.read<AppState>();
    final payUrl = await s.placeOrder();
    if (payUrl == null || !context.mounted) return;
    final ok = await PaymentWebView.open(context, payUrl);
    await s.paymentFinished(ok);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.totals;
    return Stack(children: [
      ListView(padding: EdgeInsets.only(bottom: 120 + bottomPad(context)), children: [
        ScreenHeader(title: 'Checkout', onBack: s.back),
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Text('Deliver to', style: outfit(14, weight: FontWeight.w600))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            for (final (i, a) in s.addresses.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectRow(
                  selected: s.addr == i,
                  onTap: () => s.selectAddress(i),
                  align: CrossAxisAlignment.start,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.label, style: outfit(14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(a.line, style: outfit(12.5, color: G.muted, height: 1.4)),
                  ]),
                ),
              ),
            DashedAddButton(label: '+ Add new address', onTap: () => showAddressSheet(context)),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 0), child: Text('Pay with', style: outfit(14, weight: FontWeight.w600))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            for (final m in PaymentMethod.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectRow(
                  selected: s.pay == m,
                  onTap: () => s.selectPayment(m),
                  child: Row(children: [
                    Expanded(child: Text(m.label, style: outfit(14, weight: FontWeight.w500))),
                    Text(m.hint, style: outfit(12, color: G.muted)),
                  ]),
                ),
              ),
          ]),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: cardBox(),
          child: Column(children: [
            _row('${s.cartCount} items', '₹${t.afterDiscounts}'),
            _row('Delivery', t.deliveryLabel),
            const Padding(padding: EdgeInsets.only(top: 6), child: DashedLine()),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: Text('To pay', style: outfit(16, weight: FontWeight.w700))),
                Text('₹${t.total}', style: outfit(16, weight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Text(
            s.pay == PaymentMethod.cod ? 'Your order is confirmed in Zoho right away. Pay in cash or UPI at your door.' : 'You\'ll pay securely with Zoho Payments. Your order is confirmed the moment payment succeeds.',
            textAlign: TextAlign.center,
            style: outfit(11.5, color: G.faint, height: 1.4),
          ),
        ),
      ]),
      BottomCta(child: PrimaryButton(label: s.payLabel, busy: s.placing, enabled: s.cartCount > 0, onTap: () => _place(context))),
    ]);
  }

  Widget _row(String l, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(l, style: outfit(13.5, color: G.muted))), Text(r, style: outfit(13.5))]),
      );
}
