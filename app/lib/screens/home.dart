import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = s.selectedAddress;
    return RefreshIndicator(
      color: G.plum,
      onRefresh: s.refreshCatalog,
      child: ListView(
        padding: EdgeInsets.only(bottom: 110 + bottomPad(context)),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad(context), 20, 0),
            child: Row(children: [
              Expanded(
                child: Tap(
                  onTap: () => s.go(Screen.profile),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Deliver to', style: outfit(12, color: G.muted)),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: a == null ? 'Add a delivery address ' : '${a.label} · ${a.short} '),
                        TextSpan(text: '▾', style: outfit(14, color: G.plum)),
                      ]),
                      style: outfit(14, weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              ),
              Text('gowri', style: playfair(26, color: G.plum)),
            ]),
          ),
          Tap(
            onTap: () => s.openShop(),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: cardBox(radius: 14, border: G.lineStrong),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 20, color: G.plum),
                const SizedBox(width: 10),
                Text('Search Gowri products', style: outfit(14, color: G.faint)),
              ]),
            ),
          ),
          if (s.products.isEmpty) const LoadingOrError() else ...[
            if (s.gridHome) const _GridHero() else const _EditorialHero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text('Best sellers', style: s.gridHome ? outfit(17, weight: FontWeight.w600) : playfair(21))),
                Tap(onTap: () => s.openShop(), child: Text('See all', style: outfit(13, weight: FontWeight.w500, color: G.plum))),
              ]),
            ),
            if (s.gridHome)
              _grid(context, s.products)
            else
              SizedBox(
                height: 292,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  itemCount: s.bestSellers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => Align(alignment: Alignment.topCenter, child: ProductCard(s.bestSellers[i], width: 156)),
                ),
              ),
            if (!s.gridHome && s.recommended.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 0), child: Text('Recommended for you', style: playfair(21))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(children: [
                  for (final p in s.recommended)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Tap(
                        onTap: () => s.openProduct(p.sku),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: cardBox(),
                          child: Row(children: [
                            ThumbRow(product: p),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name, style: outfit(14, weight: FontWeight.w600, height: 1.25)),
                                const SizedBox(height: 2),
                                Text('${p.size} · ${p.concern}', style: outfit(12, color: G.muted)),
                                const SizedBox(height: 4),
                                PriceBlock(p, size: 14),
                              ]),
                            ),
                            const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.chevron_right_rounded, color: G.faint)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<Product> products) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 270),
        itemCount: products.length,
        itemBuilder: (_, i) => ProductCard(products[i], imageHeight: 130, outlinedAdd: true),
      );
}

/// Option 1a: "Shop by concern" (editorial).
class _EditorialHero extends StatelessWidget {
  const _EditorialHero();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final concerns = s.concerns;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: G.plum, borderRadius: BorderRadius.circular(22)),
        child: Stack(children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(width: 170, height: 170, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('THIS WEEK', style: outfit(11, color: Colors.white.withValues(alpha: .8), letterSpacing: 1.32)),
              const SizedBox(height: 8),
              SizedBox(width: 250, child: Text('Sleep better, wake lighter', style: playfair(27, color: Colors.white, height: 1.15))),
              const SizedBox(height: 8),
              Text('Magnesium rituals, 20% off till Sunday', style: outfit(13, color: Colors.white.withValues(alpha: .85))),
              const SizedBox(height: 16),
              Tap(
                onTap: () => s.openShop(category: 'Sleep & Stress'),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Shop the ritual', style: outfit(14, weight: FontWeight.w600, color: G.plum))]),
                ),
              ),
            ]),
          ),
        ]),
      ),
      if (concerns.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 0), child: Text('Shop by concern', style: playfair(21))),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 171 / 88,
          children: [
            for (final (i, c) in concerns.indexed)
              Builder(builder: (_) {
                final col = concernColors(c.name, i);
                return Tap(
                  onTap: () => s.openShop(category: c.name),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: col.bg, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(c.name, style: outfit(15, weight: FontWeight.w600, color: col.fg)),
                      Text('${c.count} products', style: outfit(12, color: col.fg.withValues(alpha: .75))),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ],
    ]);
  }
}

/// Option 1b: "Quick-commerce grid" (category chips + offer rail).
class _GridHero extends StatelessWidget {
  const _GridHero();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final newest = s.recommended.isNotEmpty ? s.recommended.first : null;
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          itemCount: s.categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Chip2(label: s.categories[i], selected: false, onTap: () => s.setCategory(s.categories[i])),
        ),
      ),
      SizedBox(
        height: 124,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          children: [
            _OfferCard(
              bg: G.blush,
              fg: G.plum,
              kicker: 'OFFER',
              title: 'Flat 20% off on Sleep & Stress',
              sub: 'Code SLEEP20 · till Sunday',
              onTap: () => s.go(Screen.coupons),
            ),
            if (newest != null) ...[
              const SizedBox(width: 10),
              _OfferCard(
                bg: G.greenBg,
                fg: G.greenDark,
                kicker: 'NEW LAUNCH',
                title: newest.name,
                sub: 'Sunshine in a bottle · ₹${newest.price}',
                onTap: () => s.openProduct(newest.sku),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

class _OfferCard extends StatelessWidget {
  final Color bg, fg;
  final String kicker, title, sub;
  final VoidCallback onTap;
  const _OfferCard({required this.bg, required this.fg, required this.kicker, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kicker, style: outfit(11, weight: FontWeight.w600, color: fg, letterSpacing: 1.1)),
            const SizedBox(height: 6),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: outfit(19, weight: FontWeight.w600, color: fg, height: 1.2)),
            const SizedBox(height: 6),
            Text(sub, style: outfit(12.5, color: fg.withValues(alpha: .8))),
          ]),
        ),
      );
}
