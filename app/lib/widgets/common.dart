import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Header offset below the status bar (design: 64px on an iPhone with a 62px status bar).
double topPad(BuildContext c) => MediaQuery.paddingOf(c).top + 8;

/// Space below floating bottom bars (design: 30–40px over the home indicator).
double bottomPad(BuildContext c) => math.max(MediaQuery.paddingOf(c).bottom, 16);

class Tap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const Tap({super.key, this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}

BoxDecoration cardBox({double radius = 16, Color border = G.line, double borderWidth = 1, Color color = Colors.white}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border, width: borderWidth));

class StockBadge extends StatelessWidget {
  final Product product;
  final double fontSize;
  final EdgeInsets padding;
  const StockBadge(this.product, {super.key, this.fontSize = 10.5, this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3)});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>().stockOf(product);
    final (bg, fg) = switch (s.level) {
      StockLevel.out => (G.outStockBg, G.rust),
      StockLevel.low => (G.lowStockBg, G.lowStockFg),
      StockLevel.ok => (G.inStockBg, G.green),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(s.label, style: outfit(fontSize, weight: FontWeight.w600, color: fg)),
    );
  }
}

Color stockColor(BuildContext context, Product p) => switch (context.read<AppState>().stockOf(p).level) {
      StockLevel.out => G.rust,
      StockLevel.low => G.lowStockFg,
      StockLevel.ok => G.green,
    };

/// Product photo from Zoho (via the backend image proxy) over the design's tint.
class ProductImage extends StatelessWidget {
  final Product? product;
  final String sku;
  final String category;
  const ProductImage({super.key, this.product, this.sku = '', this.category = ''});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final tint = tintFor(p?.category ?? category, p?.sku ?? sku);
    return Container(
      color: tint,
      child: p?.imageUrl == null
          ? null
          : Image.network(p!.imageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox()),
    );
  }
}

class CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool translucent;
  const CircleButton({super.key, required this.onTap, required this.child, this.translucent = false});

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: translucent ? Colors.white.withValues(alpha: .92) : Colors.white,
            border: translucent ? null : Border.all(color: G.line),
          ),
          child: child,
        ),
      );
}

class BackChevron extends StatelessWidget {
  const BackChevron({super.key});
  @override
  Widget build(BuildContext context) => const Icon(Icons.chevron_left_rounded, size: 26, color: G.ink);
}

/// "‹  Title" header used by Bag, Checkout, Coupons, Returns, Tracking.
class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, topPad(context), 20, 0),
        child: Row(children: [
          CircleButton(onTap: onBack, child: const BackChevron()),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: playfair(24), overflow: TextOverflow.ellipsis)),
          ?trailing,
        ]),
      );
}

class TitleHeader extends StatelessWidget {
  final String title;
  const TitleHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, topPad(context), 20, 0), child: Text(title, style: playfair(26)));
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double radius;
  final bool enabled;
  final bool busy;
  final Widget? child;
  final Color color;
  const PrimaryButton({super.key, this.label = '', this.onTap, this.height = 54, this.radius = 16, this.enabled = true, this.busy = false, this.child, this.color = G.plum});

  @override
  Widget build(BuildContext context) => Tap(
        onTap: enabled && !busy ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: enabled ? color : G.disabled, borderRadius: BorderRadius.circular(radius)),
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : child ?? Text(label, style: outfit(15, weight: FontWeight.w600, color: Colors.white)),
        ),
      );
}

class OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  const OutlineButton({super.key, required this.label, this.onTap, this.height = 46});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: cardBox(radius: 12, border: G.lineStrong),
          child: Text(label, style: outfit(13, weight: FontWeight.w600, color: G.plum)),
        ),
      );
}

/// Sticky call-to-action over a fade, pinned to the bottom of a screen.
class BottomCta extends StatelessWidget {
  final Widget child;
  const BottomCta({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad(context) + 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, .3], colors: [Color(0x00FBF8F3), G.ivory]),
          ),
          child: child,
        ),
      );
}

class RadioDot extends StatelessWidget {
  final bool selected;
  const RadioDot(this.selected, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? G.plum : G.dashed, width: 2)),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? G.plum : Colors.transparent)),
      );
}

class SelectRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final CrossAxisAlignment align;
  const SelectRow({super.key, required this.selected, required this.onTap, required this.child, this.align = CrossAxisAlignment.center});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: cardBox(radius: 14, border: selected ? G.plum : G.line, borderWidth: 1.5),
          child: Row(crossAxisAlignment: align, children: [RadioDot(selected), const SizedBox(width: 12), Expanded(child: child)]),
        ),
      );
}

class Chip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  const Chip2({super.key, required this.label, required this.selected, required this.onTap, this.height = 36});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? G.plum : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? G.plum : G.lineStrong)),
          child: Text(label, style: outfit(13, weight: FontWeight.w500, color: selected ? Colors.white : G.ink)),
        ),
      );
}

class DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const DashedAddButton({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorder(),
          child: SizedBox(height: 44, child: Center(child: Text(label, style: outfit(13.5, weight: FontWeight.w500, color: G.plum)))),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)).deflate(.75);
    final paint = Paint()
      ..color = G.dashed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Price extends StatelessWidget {
  final int value;
  final double size;
  const Price(this.value, {super.key, this.size = 15});
  @override
  Widget build(BuildContext context) => Text('₹$value', style: outfit(size, weight: FontWeight.w700));
}

/// Product tile used in Best sellers (strike-through MRP) and Shop (% off, wishlist heart).
class ProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  final double imageHeight;
  final bool showWish;
  final bool outlinedAdd;

  const ProductCard(this.product, {super.key, this.width, this.imageHeight = 140, this.showWish = false, this.outlinedAdd = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = product;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: imageHeight,
          child: Stack(fit: StackFit.expand, children: [
            Tap(onTap: () => s.openProduct(p.sku), child: ProductImage(product: p)),
            Positioned(top: 8, left: 8, child: IgnorePointer(child: StockBadge(p))),
            if (showWish)
              Positioned(
                top: 6,
                right: 6,
                child: Tap(
                  onTap: () => s.toggleWish(p.sku),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .9)),
                    child: Icon(s.isWished(p.sku) ? Icons.favorite : Icons.favorite_border, size: 16, color: s.isWished(p.sku) ? G.rust : G.ink),
                  ),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tap(
              onTap: () => s.openProduct(p.sku),
              child: SizedBox(height: 34, child: Text(p.name, maxLines: 2, overflow: TextOverflow.clip, style: outfit(13.5, weight: FontWeight.w600, height: 1.25))),
            ),
            const SizedBox(height: 2),
            Text(p.size, style: outfit(11.5, color: G.muted)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: PriceBlock(p)),
              outlinedAdd
                  ? Tap(
                      onTap: () => s.addToCart(p.sku),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: G.plum, width: 1.5)),
                        child: Text('Add', style: outfit(12.5, weight: FontWeight.w600, color: G.plum)),
                      ),
                    )
                  : AddButton(onTap: () => s.addToCart(p.sku), enabled: p.stock > 0),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;
  const AddButton({super.key, required this.onTap, this.enabled = true});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: enabled ? G.plum : G.disabled, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        ),
      );
}

/// Horizontal row of product info used by Recommended, Wishlist, Bag.
class ThumbRow extends StatelessWidget {
  final Product? product;
  final String sku;
  final double size;
  final double radius;
  const ThumbRow({super.key, this.product, this.sku = '', this.size = 64, this.radius = 12});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(width: size, height: size, child: ProductImage(product: product, sku: sku)),
      );
}

class GowriTabBar extends StatelessWidget {
  const GowriTabBar({super.key});

  static const _tabs = [
    (Screen.home, 'Home', Icons.home_outlined, Icons.home_rounded),
    (Screen.shop, 'Shop', Icons.grid_view_outlined, Icons.grid_view_rounded),
    (Screen.cart, 'Bag', Icons.shopping_bag_outlined, Icons.shopping_bag),
    (Screen.orders, 'Orders', Icons.schedule_outlined, Icons.schedule),
    (Screen.profile, 'Me', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Positioned(
      left: 14,
      right: 14,
      bottom: bottomPad(context) - 4,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: .06)),
          boxShadow: const [BoxShadow(color: Color(0x1A2B1F27), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(children: [
          for (final (screen, name, icon, activeIcon) in _tabs)
            Expanded(
              child: Tap(
                onTap: () => s.go(screen),
                child: SizedBox(
                  height: 56,
                  child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(s.screen == screen ? activeIcon : icon, size: 21, color: s.screen == screen ? G.plum : G.tabIdle),
                      const SizedBox(height: 3),
                      Text(name, style: outfit(10.5, weight: s.screen == screen ? FontWeight.w600 : FontWeight.w500, color: s.screen == screen ? G.plum : G.tabIdle)),
                    ]),
                    if (screen == Screen.cart && s.cartCount > 0)
                      Positioned(
                        top: 6,
                        right: 14,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: G.rust, borderRadius: BorderRadius.circular(9)),
                          child: Text('${s.cartCount}', style: outfit(10.5, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class GowriToast extends StatelessWidget {
  const GowriToast({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // Always a Positioned: a plain box here would size the shell's Stack to zero.
    if (s.toast == null) return const Positioned(left: 0, bottom: 0, child: SizedBox.shrink());
    final bottom = s.showTabs ? bottomPad(context) + 76 : bottomPad(context) + 80;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(s.toast),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: G.ink, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text(s.toast!, style: outfit(13.5, weight: FontWeight.w500, color: Colors.white))),
            if (s.toastShowsBag && s.screen != Screen.cart)
              Tap(onTap: () => s.go(Screen.cart), child: Padding(padding: const EdgeInsets.only(left: 12), child: Text('View bag', style: outfit(13.5, weight: FontWeight.w600, color: G.blushText)))),
          ]),
        ),
      ),
    );
  }
}

/// Fade + rise-in used by the design for newly shown cards.
class Rise extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const Rise({super.key, required this.child, this.duration = const Duration(milliseconds: 300)});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOut,
        builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: c)),
        child: child,
      );
}

class LoadingOrError extends StatelessWidget {
  const LoadingOrError({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.catalogError != null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Text(s.catalogError!, textAlign: TextAlign.center, style: outfit(14, color: G.muted, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(width: 160, child: PrimaryButton(label: 'Try again', height: 44, radius: 12, onTap: s.refreshCatalog)),
        ]),
      );
    }
    return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: G.plum, strokeWidth: 2.4)));
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => Row(
          children: List.generate((c.maxWidth / 6).floor(), (i) => Container(width: 3, height: 1, margin: const EdgeInsets.only(right: 3), color: G.lineStrong)),
        ),
      );
}

/// Selling price, MRP struck through, and the saving, e.g. "₹270 ₹395 / 32% off".
class PriceBlock extends StatelessWidget {
  final Product product;
  final double size;
  const PriceBlock(this.product, {super.key, this.size = 15});
  @override
  Widget build(BuildContext context) {
    final p = product;
    final discounted = p.mrp > p.price;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '₹${p.price}', style: outfit(size, weight: FontWeight.w700)),
          if (discounted) TextSpan(text: '  ₹${p.mrp}', style: outfit(size * .77, color: G.faint, decoration: TextDecoration.lineThrough)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
      if (discounted) Text('${p.off}% off', style: outfit(size * .75, weight: FontWeight.w600, color: G.green)),
    ]);
  }
}
