import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/address_sheet.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.customer;
    final rows = <(String, String, VoidCallback)>[
      ('Coupons & offers', '${s.coupons.length} available', () => s.go(Screen.coupons)),
      ('GST invoices', 'From Zoho Books', () => s.go(Screen.orders)),
      ('Help & support', 'WhatsApp', () => launchUrl(Uri.parse('https://wa.me/${AppConfig.supportWhatsApp}'), mode: LaunchMode.externalApplication)),
      ('About Gowri', '', () => launchUrl(Uri.parse(AppConfig.websiteUrl), mode: LaunchMode.externalApplication)),
    ];
    return ListView(padding: EdgeInsets.only(bottom: 110 + bottomPad(context)), children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, topPad(context), 20, 0),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: G.plum),
            child: Text(c?.initial ?? 'G', style: playfair(22, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c?.hasRealName == true ? c!.name : 'Welcome to Gowri', style: outfit(18, weight: FontWeight.w600)),
              Text('+91 ${c?.phone ?? s.phone} · Member since ${c?.memberSince ?? ''}', style: outfit(13, color: G.muted)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Row(children: [
          Expanded(child: _Stat(value: '${s.orders.length}', label: 'Orders', onTap: () => s.go(Screen.orders))),
          const SizedBox(width: 8),
          Expanded(child: _Stat(value: '${s.wish.length}', label: 'Saved', onTap: () => s.go(Screen.wishlist))),
          const SizedBox(width: 8),
          Expanded(child: _Stat(value: '${s.coupons.length}', label: 'Coupons', onTap: () => s.go(Screen.coupons))),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 0), child: Text('Saved addresses', style: outfit(14, weight: FontWeight.w600))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(children: [
          for (final (i, a) in s.addresses.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: cardBox(radius: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: a.label, style: outfit(14, weight: FontWeight.w600)),
                      if (i == s.addr) TextSpan(text: '   DEFAULT', style: outfit(11, weight: FontWeight.w600, color: G.plum)),
                    ])),
                    const SizedBox(height: 2),
                    Text(a.line, style: outfit(12.5, color: G.muted, height: 1.4)),
                  ]),
                ),
                if (i != s.addr) Tap(onTap: () => s.selectAddress(i), child: Text('Use', style: outfit(13, weight: FontWeight.w500, color: G.plum))),
              ]),
            ),
          DashedAddButton(label: '+ Add new address', onTap: () => showAddressSheet(context)),
        ]),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        clipBehavior: Clip.antiAlias,
        decoration: cardBox(),
        child: Column(children: [
          for (final (i, (name, hint, onTap)) in rows.indexed)
            Tap(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: G.rowDivider))),
                child: Row(children: [
                  Expanded(child: Text(name, style: outfit(14))),
                  Text(hint, style: outfit(12, color: G.muted)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: G.faint),
                ]),
              ),
            ),
        ]),
      ),
      Tap(
        onTap: s.logout,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          height: 46,
          alignment: Alignment.center,
          child: Text('Log out', style: outfit(14, weight: FontWeight.w500, color: G.rust)),
        ),
      ),
      if (s.api.isDemo)
        Center(
          child: Tap(
            onTap: s.toggleGridHome,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Demo · switch Home to ${s.gridHome ? '"Shop by concern"' : '"Quick-commerce grid"'}', style: outfit(11.5, color: G.faint)),
            ),
          ),
        ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final VoidCallback onTap;
  const _Stat({required this.value, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: cardBox(radius: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: outfit(20, weight: FontWeight.w700)),
            Text(label, style: outfit(12, color: G.muted)),
          ]),
        ),
      );
}
