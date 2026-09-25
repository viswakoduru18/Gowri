import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pad = MediaQuery.paddingOf(context);
    // Fixed-height page (at least 720px) so the card can sit at the bottom without
    // intrinsic measurement; scrolls when the keyboard is open or the phone is small.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: Container(
          width: double.infinity,
          height: box.maxHeight < 720 ? 720 : box.maxHeight,
          // Plum top 46%, ivory below (hard stop), as in the design.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .46, .461, 1],
              colors: [G.plum, G.plum, G.ivory, G.ivory],
            ),
          ),
          padding: EdgeInsets.fromLTRB(28, pad.top + 50, 28, pad.bottom + 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('gowri', style: playfair(46, color: Colors.white, height: 1)),
              const SizedBox(height: 8),
              Text('FOR A BEAUTIFUL LIFE', style: outfit(13, color: Colors.white.withValues(alpha: .85), letterSpacing: 1.04)),
              const SizedBox(height: 60),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text('Small daily rituals, delivered to your door.', style: playfair(26, color: Colors.white, italic: true, height: 1.25)),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x1A2B1F27), blurRadius: 30, offset: Offset(0, 10))],
                ),
                child: s.otpStage ? const _OtpStage() : const _PhoneStage(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneStage extends StatefulWidget {
  const _PhoneStage();
  @override
  State<_PhoneStage> createState() => _PhoneStageState();
}

class _PhoneStageState extends State<_PhoneStage> {
  late final _ctrl = TextEditingController(text: context.read<AppState>().phone);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Hi there, let's get you in", style: outfit(18, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text("We'll text you a one-time code. No passwords.", style: outfit(13, color: G.muted)),
        const SizedBox(height: 16),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: cardBox(radius: 12, border: G.lineInput, borderWidth: 1.5, color: G.ivory),
          child: Row(
            children: [
              Text(
                '+91',
                style: outfit(16, weight: FontWeight.w600, color: G.plum),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: s.setPhone,
                  onSubmitted: (_) => s.sendOtp(),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  style: outfit(18, weight: FontWeight.w500, letterSpacing: .72),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isCollapsed: true,
                    hintText: 'Mobile number',
                    hintStyle: outfit(18, color: G.faint),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Send code', radius: 14, enabled: s.phoneValid, busy: s.authBusy, onTap: s.sendOtp),
        if (s.authError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              s.authError!,
              textAlign: TextAlign.center,
              style: outfit(12.5, color: G.rust),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          "By continuing you agree to Gowri's Terms & Privacy Policy",
          textAlign: TextAlign.center,
          style: outfit(11.5, color: G.faint, height: 1.4),
        ),
      ],
    );
  }
}

class _OtpStage extends StatelessWidget {
  const _OtpStage();

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the 4-digit code', style: outfit(18, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: outfit(13, color: G.muted),
            children: [
              TextSpan(text: 'Sent to +91 ${s.phone} · '),
              WidgetSpan(
                child: Tap(
                  onTap: s.backToPhone,
                  child: Text(
                    'change',
                    style: outfit(13, weight: FontWeight.w500, color: G.plum),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: cardBox(radius: 12, border: i == s.otp.length ? G.plum : G.lineInput, borderWidth: 1.5, color: G.ivory),
                  child: Text(i < s.otp.length ? s.otp[i] : '', style: outfit(24, weight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          padding: EdgeInsets.zero,
          children: [
            for (final k in _keys)
              Tap(
                onTap: () => s.keypad(k),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: k.isEmpty ? Colors.transparent : (k == '⌫' ? G.blush : G.key), borderRadius: BorderRadius.circular(10)),
                  child: k == '⌫' ? const Icon(Icons.backspace_outlined, size: 20, color: G.ink) : Text(k, style: outfit(20, weight: FontWeight.w500)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (s.authBusy)
          const Center(
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: G.plum)),
          )
        else if (s.authError != null)
          Text(
            s.authError!,
            textAlign: TextAlign.center,
            style: outfit(12, color: G.rust),
          )
        else if (s.api.isDemo)
          Text(
            'Demo: any 4 digits work',
            textAlign: TextAlign.center,
            style: outfit(12, color: G.muted),
          )
        else
          Tap(
            onTap: s.sendOtp,
            child: Text(
              'Resend code',
              textAlign: TextAlign.center,
              style: outfit(12, weight: FontWeight.w500, color: G.plum),
            ),
          ),
      ],
    );
  }
}
