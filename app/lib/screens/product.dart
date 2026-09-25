import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.products.isEmpty) return const LoadingOrError();
    final p = s.product;
    final inCart = s.cart[p.sku] ?? 0;
    final wished = s.isWished(p.sku);
    final top = MediaQuery.paddingOf(context).top;
    final eta = p.stock == 0 ? 'Notify me' : 'In 2–3 days · free above ₹499';
    return Stack(children: [
      ListView(padding: EdgeInsets.only(bottom: 120 + bottomPad(context)), children: [
        SizedBox(
          height: 380,
          child: Stack(fit: StackFit.expand, children: [
            ProductImage(product: p),
            Positioned(top: top + 4, left: 16, child: CircleButton(translucent: true, onTap: s.back, child: const BackChevron())),
            Positioned(
              top: top + 4,
              right: 16,
              child: CircleButton(
                translucent: true,
                onTap: () => s.toggleWish(p.sku),
                child: Icon(wished ? Icons.favorite : Icons.favorite_border, size: 19, color: wished ? G.rust : G.ink),
              ),
            ),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -24),
          child: Container(
            decoration: const BoxDecoration(color: G.ivory, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p.category} · ${p.size}'.toUpperCase(), style: outfit(11.5, color: G.muted, letterSpacing: .69)),
                    const SizedBox(height: 4),
                    Text(p.name, style: playfair(24, height: 1.2)),
                  ]),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: StockBadge(p, fontSize: 11.5, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                ),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('₹${p.price}', style: outfit(28, weight: FontWeight.w700)),
                const SizedBox(width: 10),
                if (p.mrp > p.price) ...[
                  Text('MRP ₹${p.mrp}', style: outfit(15, color: G.faint, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 10),
                  Text('${p.off}% off', style: outfit(13, weight: FontWeight.w600, color: G.green)),
                ],
              ]),
              const SizedBox(height: 2),
              Text('Inclusive of ${p.gst}% GST · SKU ${p.sku}', style: outfit(12, color: G.muted)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _InfoTile(label: 'Delivery', value: eta)),
                const SizedBox(width: 10),
                Expanded(child: _InfoTile(label: 'Ships from', value: p.warehouse)),
              ]),
              const SizedBox(height: 22),
              for (final sec in p.sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sec.title, style: outfit(14, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(sec.body, style: outfit(13.5, color: G.body, height: 1.55)),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
      BottomCta(
        child: Row(children: [
          Expanded(
            child: Tap(
              onTap: () => p.stock == 0 ? s.showToast("Out of stock — we'll notify you", bag: false) : s.addToCart(p.sku),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: G.ivory, borderRadius: BorderRadius.circular(16), border: Border.all(color: G.plum, width: 1.5)),
                child: Text(p.stock == 0 ? 'Notify me' : (inCart > 0 ? 'In bag · $inCart' : 'Add to bag'), style: outfit(15, weight: FontWeight.w600, color: G.plum)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(label: 'Buy now', onTap: () => s.buyNow(p.sku))),
        ]),
      ),
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: cardBox(radius: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: outfit(11, color: G.muted)),
          const SizedBox(height: 2),
          Text(value, style: outfit(13.5, weight: FontWeight.w600)),
        ]),
      );
}
