import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final _coupon = TextEditingController(text: context.read<AppState>().couponInput);

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (_coupon.text != s.couponInput) _coupon.text = s.couponInput;
    final t = s.totals;
    final empty = s.cartCount == 0;
    return Stack(children: [
      ListView(padding: EdgeInsets.only(bottom: 180 + bottomPad(context)), children: [
        ScreenHeader(title: 'Your bag', onBack: s.back, trailing: Text('${s.cartCount} items', style: outfit(13, color: G.muted))),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
            child: Column(children: [
              Text('Your bag is empty', style: playfair(22)),
              const SizedBox(height: 8),
              Text('Good things are waiting. Start with a best seller.', textAlign: TextAlign.center, style: outfit(14, color: G.muted, height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(width: 190, child: PrimaryButton(label: 'Browse products', height: 48, radius: 14, onTap: () => s.openShop())),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            for (final it in t.items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: cardBox(),
                child: Row(children: [
                  ThumbRow(product: it.product, size: 68),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.product.name, style: outfit(14, weight: FontWeight.w600, height: 1.25)),
                      const SizedBox(height: 2),
                      Text(it.product.size, style: outfit(12, color: G.muted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Price(it.lineTotal)),
                        Container(
                          height: 34,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: G.lineStrong)),
                          child: Row(children: [
                            _QtyBtn(icon: Icons.remove_rounded, onTap: () => s.setQty(it.product.sku, -1)),
                            SizedBox(width: 26, child: Text('${it.qty}', textAlign: TextAlign.center, style: outfit(14, weight: FontWeight.w600))),
                            _QtyBtn(icon: Icons.add_rounded, onTap: () => s.setQty(it.product.sku, 1)),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
        if (!empty) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: cardBox(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: cardBox(radius: 10, border: G.lineStrong, color: G.ivory),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _coupon,
                      onChanged: s.setCouponInput,
                      onSubmitted: (_) => s.applyCoupon(),
                      textCapitalization: TextCapitalization.characters,
                      style: outfit(14),
                      decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: 'Coupon code', hintStyle: outfit(14, color: G.faint)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tap(
                  onTap: s.applyCoupon,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: G.plum, borderRadius: BorderRadius.circular(10)),
                    child: Text('Apply', style: outfit(13, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ]),
              if (s.couponMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.couponMsg, style: outfit(12.5, color: s.couponOk ? G.green : G.rust))),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: cardBox(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _SumRow('Item total (MRP)', '₹${t.mrp}'),
              _SumRow('Gowri discount', '−₹${t.discount}', green: true),
              _SumRow('Coupon', '−₹${t.coupon}', green: true),
              _SumRow('Delivery', t.deliveryLabel),
              const Padding(padding: EdgeInsets.only(top: 6), child: DashedLine()),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Row(children: [
                  Expanded(child: Text('To pay', style: outfit(16, weight: FontWeight.w700))),
                  Text('₹${t.total}', style: outfit(16, weight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 2),
              Text('Includes ₹${t.gst} GST · invoice from Zoho Books after delivery', style: outfit(11.5, color: G.faint)),
            ]),
          ),
        ],
      ]),
      if (!empty)
        BottomCta(
          child: PrimaryButton(
            onTap: () => s.go(Screen.checkout),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text('Checkout', style: outfit(15, weight: FontWeight.w600, color: Colors.white))),
                Text('₹${t.total} ›', style: outfit(15, weight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Tap(onTap: onTap, child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: G.plum)));
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final bool green;
  const _SumRow(this.label, this.value, {this.green = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: outfit(13.5, color: G.muted))),
          Text(value, style: outfit(13.5, color: green ? G.green : G.ink)),
        ]),
      );
}
