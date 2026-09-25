import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Name and email for the customer's Zoho contact. Shown once after first
/// sign-in (onboarding) and from Profile → Edit.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppState _s = context.read<AppState>();
  late final _name = TextEditingController(text: _s.customer?.hasRealName == true ? _s.customer!.name : '');
  late final _email = TextEditingController(text: _s.customer?.email ?? '');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController c, {String? hint, TextInputType? type, List<String>? autofill, TextCapitalization caps = TextCapitalization.none}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: outfit(13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: cardBox(radius: 12, border: G.lineStrong),
            child: TextField(
              controller: c,
              keyboardType: type,
              autofillHints: autofill,
              textCapitalization: caps,
              style: outfit(15),
              decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: hint, hintStyle: outfit(15, color: G.faint)),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final onboarding = s.onboardingProfile;
    return ListView(padding: EdgeInsets.only(bottom: 40 + bottomPad(context)), children: [
      if (onboarding)
        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad(context) + 8, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome to Gowri', style: playfair(26)),
            const SizedBox(height: 6),
            Text('Tell us your name so we can address your orders and GST invoices correctly.', style: outfit(14, color: G.muted, height: 1.5)),
          ]),
        )
      else
        ScreenHeader(title: 'Your details', onBack: s.back),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field('Full name', _name, hint: 'e.g. Ananya Rao', autofill: const [AutofillHints.name], caps: TextCapitalization.words),
          const SizedBox(height: 16),
          _field('Email (for invoices, optional)', _email, hint: 'you@example.com', type: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
          const SizedBox(height: 16),
          Text('Mobile', style: outfit(13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('+91 ${s.customer?.phone ?? s.phone}', style: outfit(15, color: G.muted)),
          if (s.profileError != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(s.profileError!, style: outfit(13, color: G.rust))),
          const SizedBox(height: 24),
          PrimaryButton(label: onboarding ? 'Continue' : 'Save', busy: s.profileBusy, onTap: () => s.saveProfile(_name.text, _email.text)),
          if (onboarding)
            Tap(
              onTap: s.skipProfile,
              child: Padding(padding: const EdgeInsets.all(14), child: Text('Skip for now', textAlign: TextAlign.center, style: outfit(13.5, weight: FontWeight.w500, color: G.muted))),
            ),
        ]),
      ),
    ]);
  }
}
