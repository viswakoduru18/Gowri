import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final _q = TextEditingController(text: context.read<AppState>().query);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.filtered;
    final hasQuery = s.query.trim().isNotEmpty;
    return RefreshIndicator(
      color: G.plum,
      onRefresh: s.refreshCatalog,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topPad(context), 20, 0),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: cardBox(radius: 14, border: hasQuery ? G.plum : G.lineStrong, borderWidth: 1.5),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 20, color: G.plum),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _q,
                    onChanged: s.setQuery,
                    textInputAction: TextInputAction.search,
                    style: outfit(14),
                    decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: 'Search products, concerns, SKUs', hintStyle: outfit(14, color: G.faint)),
                  ),
                ),
                if (hasQuery)
                  Tap(
                    onTap: () {
                      _q.clear();
                      s.setQuery('');
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: G.lineStrong),
                      child: const Icon(Icons.close_rounded, size: 14, color: G.ink),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              itemCount: s.categories.length + (s.categories.contains(s.cat) || s.cat == 'All' ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                // A concern picked from Home shows as its own selected chip.
                final names = [...s.categories, if (!s.categories.contains(s.cat)) s.cat];
                return Chip2(label: names[i], selected: s.cat == names[i], onTap: () => s.setCategory(names[i]));
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('${items.length} products · prices & stock live from Zoho Inventory', style: outfit(12.5, color: G.muted)),
          ),
        ),
        if (s.products.isEmpty)
          const SliverToBoxAdapter(child: LoadingOrError())
        else if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Text('Nothing matched. Try "magnesium" or "glow".', textAlign: TextAlign.center, style: outfit(14, color: G.muted)),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 110 + bottomPad(context)),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 264),
              itemCount: items.length,
              itemBuilder: (_, i) => Rise(key: ValueKey('${s.cat}|${items[i].sku}'), child: ProductCard(items[i], showOff: true, showWish: true)),
            ),
          ),
      ]),
    );
  }
}
