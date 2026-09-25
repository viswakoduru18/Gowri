import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Hosts the backend's Zoho Payments checkout page. Closes itself when the
/// page reaches /pay/:id/done and reports whether the payment succeeded.
/// The backend has already verified the payment with Zoho by then.
class PaymentWebView extends StatefulWidget {
  final String url;
  const PaymentWebView({super.key, required this.url});

  static Future<bool> open(BuildContext context, String url) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaymentWebView(url: url)));
    return ok ?? false;
  }

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _web;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(G.ivory)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => mounted ? setState(() => _loading = false) : null,
        onNavigationRequest: (req) {
          final uri = Uri.parse(req.url);
          if (uri.path.endsWith('/done')) {
            Navigator.of(context).pop(uri.queryParameters['status'] == 'success');
            return NavigationDecision.prevent;
          }
          // UPI intent links (upi://, tez://, phonepe://, paytmmp://, intent://) open the customer's UPI app.
          if (!uri.scheme.startsWith('http')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: G.ivory,
        body: Stack(children: [
          Positioned.fill(top: MediaQuery.paddingOf(context).top + 56, child: WebViewWidget(controller: _web)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 8),
              child: Row(children: [
                CircleButton(onTap: () => Navigator.of(context).pop(false), child: const Icon(Icons.close_rounded, size: 20, color: G.ink)),
                const SizedBox(width: 12),
                Text('Secure payment', style: playfair(22)),
                const Spacer(),
                const Icon(Icons.lock_outline_rounded, size: 18, color: G.green),
              ]),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator(color: G.plum, strokeWidth: 2.4)),
        ]),
      );
}
