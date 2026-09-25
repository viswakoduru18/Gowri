import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'payment_webview.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  Future<void> _invoice(BuildContext context) async {
    final url = await context.read<AppState>().invoiceLink();
    if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _retryPay(BuildContext context) async {
    final s = context.read<AppState>();
    final url = await s.retryPayment();
    if (url == null || !context.mounted) return;
    await s.paymentFinished(await PaymentWebView.open(context, url));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = s.order;
    if (o == null) return const SizedBox();
    final name = s.customer?.firstName ?? '';
    return ListView(padding: EdgeInsets.only(bottom: 120 + bottomPad(context)), children: [
      ScreenHeader(title: 'Order ${o.id}', onBack: s.goOrders),
      if (s.justPlaced)
        Rise(
          duration: const Duration(milliseconds: 400),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: G.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: G.green),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(name.isEmpty ? 'Thank you!' : 'Thank you, $name!', style: playfair(24, color: G.greenDark)),
              const SizedBox(height: 6),
              Text('Your order is confirmed. Sales Order ${o.zohoSo} is created in Zoho and your items are reserved.', style: outfit(13.5, color: G.greenDark, height: 1.5)),
            ]),
          ),
        ),
      if (o.awaitingPayment)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: G.lowStockBg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Payment pending', style: outfit(15, weight: FontWeight.w600, color: G.lowStockFg)),
            const SizedBox(height: 4),
            Text('Your items are held for a short while. Complete payment to confirm the order.', style: outfit(13, color: G.lowStockFg, height: 1.45)),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Complete payment · ₹${o.total}', height: 46, radius: 12, onTap: () => _retryPay(context)),
          ]),
        ),
      Container(
        margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(o.delivered ? 'D${o.eta.substring(1)}' : 'Arriving ${o.eta}', style: outfit(14, weight: FontWeight.w600))),
            Flexible(child: Text(o.courier, textAlign: TextAlign.right, style: outfit(12, color: G.muted))),
          ]),
          const SizedBox(height: 16),
          for (final (i, st) in o.steps.indexed) _StepRow(step: st, last: i == o.steps.length - 1),
          if (o.trackingUrl != null && !o.delivered)
            Tap(
              onTap: () => launchUrl(Uri.parse(o.trackingUrl!), mode: LaunchMode.externalApplication),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: G.blush, borderRadius: BorderRadius.circular(12)),
                child: Text('Track rider live', style: outfit(13.5, weight: FontWeight.w600, color: G.plum)),
              ),
            ),
        ]),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(14),
        decoration: cardBox(),
        child: Column(children: [
          for (final it in o.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                ThumbRow(product: s.bySku(it.sku), sku: it.sku, size: 44, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${it.name} ', style: outfit(13.5, weight: FontWeight.w500)),
                    TextSpan(text: '× ${it.qty}', style: outfit(13.5, weight: FontWeight.w500, color: G.muted)),
                  ])),
                ),
                Text('₹${it.lineTotal}', style: outfit(13.5, weight: FontWeight.w600)),
              ]),
            ),
          const DashedLine(),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(child: Text('${o.awaitingPayment ? 'To pay' : (o.payment == PaymentMethod.cod.label ? 'Pay on delivery' : 'Paid')} · ${o.payment}', style: outfit(14, weight: FontWeight.w700))),
              Text('₹${o.total}', style: outfit(14, weight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(children: [
          Expanded(child: OutlineButton(label: 'GST invoice', onTap: () => _invoice(context))),
          const SizedBox(width: 10),
          Expanded(child: OutlineButton(label: 'Return / help', onTap: s.openReturns)),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(height: 46, radius: 12, onTap: s.reorder, child: Text('Reorder', style: outfit(13, weight: FontWeight.w600, color: Colors.white)))),
        ]),
      ),
    ]);
  }
}

class _StepRow extends StatefulWidget {
  final OrderStep step;
  final bool last;
  const _StepRow({required this.step, required this.last});
  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _StepRow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.step.state == StepStatus.current) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.step;
    final active = st.state != StepStatus.pending;
    return IntrinsicHeight(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 20,
            child: Column(children: [
              AnimatedBuilder(
                animation: _pulse,
                // Design: opacity 1 → .35 → 1 over 1.4s on the current step.
                builder: (_, child) => Opacity(opacity: 1 - .65 * (1 - (2 * _pulse.value - 1).abs()), child: child),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: active ? G.plum : Colors.white, border: Border.all(color: active ? G.plum : G.dashed, width: 3)),
                ),
              ),
              if (!widget.last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: st.state == StepStatus.done ? G.plum : G.lineStrong)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.title, style: outfit(14, weight: FontWeight.w600, color: active ? G.ink : G.faint, height: 1)),
                const SizedBox(height: 2),
                Text(st.sub, style: outfit(12.5, color: G.muted)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
