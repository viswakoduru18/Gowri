import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'data/api.dart';
import 'data/http_api.dart';
import 'data/mock_api.dart';
import 'screens/cart.dart';
import 'screens/checkout.dart';
import 'screens/edit_profile.dart';
import 'screens/home.dart';
import 'screens/lists.dart';
import 'screens/login.dart';
import 'screens/product.dart';
import 'screens/profile.dart';
import 'screens/shop.dart';
import 'screens/tracking.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in google_fonts/ so the first launch looks right offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final f in ['Outfit', 'PlayfairDisplay']) {
      yield LicenseEntryWithLineBreaks(['google_fonts'], await rootBundle.loadString('google_fonts/OFL-$f.txt'));
    }
  });
  final GowriApi api = AppConfig.apiBaseUrl.isEmpty ? MockGowriApi() : HttpGowriApi(AppConfig.apiBaseUrl);
  runApp(GowriApp(api: api));
}

class GowriApp extends StatelessWidget {
  final GowriApi api;
  const GowriApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AppState(api, gridHomeDefault: AppConfig.homeLayout == 'grid', lowStockThreshold: AppConfig.lowStockThreshold)..boot(),
        child: MaterialApp(
          title: 'Gowri',
          debugShowCheckedModeBanner: false,
          theme: gowriTheme(),
          home: const AppShell(),
        ),
      );
}

/// One screen at a time plus the floating tab bar and toast, as in the design.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  Widget _screen(Screen s) => switch (s) {
        Screen.login => const LoginScreen(),
        Screen.home => const HomeScreen(),
        Screen.shop => const ShopScreen(),
        Screen.product => const ProductScreen(),
        Screen.cart => const CartScreen(),
        Screen.checkout => const CheckoutScreen(),
        Screen.tracking => const TrackingScreen(),
        Screen.orders => const OrdersScreen(),
        Screen.wishlist => const WishlistScreen(),
        Screen.coupons => const CouponsScreen(),
        Screen.returns => const ReturnsScreen(),
        Screen.profile => const ProfileScreen(),
        Screen.editProfile => const EditProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final light = s.screen == Screen.login;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        // Android back follows the in-app history; at Home/Login it leaves the app.
        canPop: !s.canGoBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) s.back();
        },
        child: Scaffold(
          backgroundColor: G.ivory,
          resizeToAvoidBottomInset: s.screen == Screen.login,
          body: s.booting
              ? const Center(child: CircularProgressIndicator(color: G.plum, strokeWidth: 2.4))
              : Stack(fit: StackFit.expand, children: [
                  Positioned.fill(child: KeyedSubtree(key: ValueKey(s.screen), child: _screen(s.screen))),
                  if (s.showTabs) const GowriTabBar(),
                  const GowriToast(),
                ]),
        ),
      ),
    );
  }
}
