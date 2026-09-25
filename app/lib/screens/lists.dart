import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return RefreshIndicator(
      color: G.plum,
      onRefresh: s.loadOrders,
      child: ListView(padding: EdgeInsets.only(bottom: 110 + bottomPad(context)), children: [
        const TitleHeader('My orders'),
        if (s.orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
            child: Column(children: [
              Text('No orders yet', style: playfair(22)),
              const SizedBox(height: 8),
              Text('Your orders and their live status from Zoho show up here.', textAlign: TextAlign.center, style: outfit(14, color: G.muted, height: 1.5)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            for (final o in s.orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Tap(
                  onTap: () => s.openOrder(o),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardBox(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(o.id, style: outfit(14, weight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: o.delivered ? G.inStockBg : (o.awaitingPayment ? G.lowStockBg : G.blush),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(o.status, style: outfit(11.5, weight: FontWeight.w600, color: o.delivered ? G.green : (o.awaitingPayment ? G.lowStockFg : G.plum))),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(o.summary, style: outfit(12.5, color: G.muted)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: Text(o.date, style: outfit(13, color: G.muted))),
                        Text('₹${o.total}', style: outfit(13, weight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.wishItems;
    return ListView(padding: EdgeInsets.only(bottom: 110 + bottomPad(context)), children: [
      const TitleHeader('Wishlist'),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
          child: Column(children: [
            Text('Nothing saved yet', style: playfair(22)),
            const SizedBox(height: 8),
            Text('Tap the heart on any product to keep it here.', textAlign: TextAlign.center, style: outfit(14, color: G.muted)),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          for (final p in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: cardBox(),
              child: Row(children: [
                Tap(onTap: () => s.openProduct(p.sku), child: ThumbRow(product: p)),
                const SizedBox(width: 12),
                Expanded(
                  child: Tap(
                    onTap: () => s.openProduct(p.sku),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: outfit(14, weight: FontWeight.w600, height: 1.25)),
                      const SizedBox(height: 2),
                      Text('${s.stockOf(p).label} · ₹${p.price}', style: outfit(12, weight: FontWeight.w500, color: stockColor(context, p))),
                    ]),
                  ),
                ),
                Tap(
                  onTap: () => s.addToCart(p.sku),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.stock > 0 ? G.plum : G.disabled, borderRadius: BorderRadius.circular(10)),
                    child: Text('Add', style: outfit(12.5, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                Tap(onTap: () => s.toggleWish(p.sku), child: const SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, size: 18, color: G.faint))),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(padding: EdgeInsets.only(bottom: 110 + bottomPad(context)), children: [
      ScreenHeader(title: 'Offers & coupons', onBack: s.back),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          for (final c in s.coupons)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              decoration: cardBox(),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    width: 64,
                    color: G.plum,
                    alignment: Alignment.center,
                    child: RotatedBox(quarterTurns: 3, child: Text(c.value, style: outfit(15, weight: FontWeight.w700, color: Colors.white, letterSpacing: .9))),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.code, style: outfit(15, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(c.desc, style: outfit(12.5, color: G.muted, height: 1.4)),
                        const SizedBox(height: 10),
                        Tap(
                          onTap: () => s.useCoupon(c),
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: G.plum)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(s.coupon?.code == c.code && s.couponOk ? 'Applied' : 'Apply to bag', style: outfit(12.5, weight: FontWeight.w600, color: G.plum)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = s.order;
    if (o == null) return const SizedBox();
    return ListView(padding: EdgeInsets.only(bottom: 110 + bottomPad(context)), children: [
      ScreenHeader(title: 'Return an item', onBack: s.back),
      if (s.retDone)
        Rise(
          duration: const Duration(milliseconds: 400),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: G.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Return requested', style: playfair(22, color: G.greenDark)),
              const SizedBox(height: 6),
              Text(
                "We'll pick it up in 2 days. Refund of ₹${s.retAmount} reaches you within 5 days of pickup (credit note in Zoho Books).",
                style: outfit(13.5, color: G.greenDark, height: 1.5),
              ),
              const SizedBox(height: 14),
              Tap(
                onTap: s.goOrders,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(color: G.green, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Back to orders', style: outfit(13.5, weight: FontWeight.w600, color: Colors.white))]),
                ),
              ),
            ]),
          ),
        )
      else ...[
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Text('From order ${o.id}', style: outfit(14, weight: FontWeight.w600))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            for (final it in o.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tap(
                  onTap: () => s.toggleReturnItem(it.sku),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: cardBox(radius: 14, border: s.retSel.contains(it.sku) ? G.plum : G.line, borderWidth: 1.5),
                    child: Row(children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: s.retSel.contains(it.sku) ? G.plum : Colors.transparent,
                          border: Border.all(color: s.retSel.contains(it.sku) ? G.plum : G.dashed, width: 2),
                        ),
                        child: s.retSel.contains(it.sku) ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(it.name, style: outfit(13.5, weight: FontWeight.w500))),
                      Text('₹${it.lineTotal}', style: outfit(13, weight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Text('Reason', style: outfit(14, weight: FontWeight.w600))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in returnReasons) Chip2(label: r, height: 38, selected: s.retReason == r, onTap: () => s.setReturnReason(r)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            "Sealed wellness products can be returned within 7 days of delivery. Opened consumables can't be returned, but tell us what went wrong and we'll make it right.",
            style: outfit(12.5, color: G.muted, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: PrimaryButton(label: 'Request pickup', enabled: s.returnSelectionTotal > 0 && s.retReason != null, busy: s.retBusy, onTap: s.submitReturn),
        ),
      ],
    ]);
  }
}
