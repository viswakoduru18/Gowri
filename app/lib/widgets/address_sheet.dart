import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom sheet for adding a delivery address (saved on the customer's Zoho contact).
Future<void> showAddressSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: G.ivory,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ChangeNotifierProvider.value(value: context.read<AppState>(), child: const _AddressForm()),
    );

class _AddressForm extends StatefulWidget {
  const _AddressForm();
  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController(text: 'Hyderabad');
  final _state = TextEditingController(text: 'Telangana');
  final _pin = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _line1, _line2, _city, _state, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().addAddress(NewAddress(
            label: _label.text.trim(),
            line1: _line1.text.trim(),
            line2: _line2.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            pincode: _pin.text.trim(),
          ));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String hint, {String? Function(String)? validate, TextInputType? type, int? maxLength}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          maxLength: maxLength,
          style: outfit(14),
          validator: (v) => validate?.call(v?.trim() ?? ''),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: outfit(14, color: G.faint),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: G.lineStrong)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: G.plum, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: G.rust)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: G.rust, width: 1.5)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    String? required(String v) => v.length < 2 ? 'Required' : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + bottomPad(context)),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('New address', style: playfair(22)),
            const SizedBox(height: 14),
            _field(_label, 'Label (Home, Office…)', validate: required),
            _field(_line1, 'House / flat, street', validate: (v) => v.length < 3 ? 'Enter your street address' : null),
            _field(_line2, 'Area, landmark (optional)'),
            Row(children: [
              Expanded(child: _field(_city, 'City', validate: required)),
              const SizedBox(width: 10),
              Expanded(child: _field(_state, 'State', validate: required)),
            ]),
            _field(_pin, 'PIN code', type: TextInputType.number, maxLength: 6, validate: (v) => RegExp(r'^\d{6}$').hasMatch(v) ? null : 'Enter a 6-digit PIN code'),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: outfit(12.5, color: G.rust))),
            PrimaryButton(label: 'Save address', busy: _saving, onTap: _save),
          ]),
        ),
      ),
    );
  }
}
