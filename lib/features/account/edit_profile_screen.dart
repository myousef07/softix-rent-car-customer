import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../widgets/common.dart';

/// The details a renter may change themselves: e-mail and national address.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _profile = ref.read(sessionProvider).profile!;
  late final _email = TextEditingController(text: _profile.email);
  late final _city = TextEditingController(text: _profile.address.city);
  late final _district = TextEditingController(text: _profile.address.district);
  late final _street = TextEditingController(text: _profile.address.street);
  late final _building = TextEditingController(text: _profile.address.buildingNumber);
  late final _postal = TextEditingController(text: _profile.address.postalCode);
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_email, _city, _district, _street, _building, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String? value(TextEditingController c) => c.text.trim().isEmpty ? null : westernDigits(c.text.trim());

    setState(() => _error = null);
    try {
      await ref.read(repositoryProvider).updateProfile({
        'email': value(_email),
        'city': value(_city),
        'district': value(_district),
        'street': value(_street),
        'building_number': value(_building),
        'postal_code': value(_postal),
      });
      await ref.read(sessionProvider).reloadProfile();
      if (!mounted) return;
      showSuccess(context, 'تم حفظ بياناتك.');
      context.pop();
    } catch (error) {
      if (!mounted) return;
      final failure = ApiException.from(error);
      setState(() => _error = failure);
      if (failure.fieldErrors.isEmpty) showError(context, failure);
    }
  }

  Widget _field(TextEditingController controller, String label, String field, {TextInputType? keyboard, bool ltr = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(labelText: label, errorText: fieldError(_error, field)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('البريد والعنوان')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(_email, 'البريد الإلكتروني', 'email', keyboard: TextInputType.emailAddress, ltr: true),
        const SizedBox(height: 8),
        const Text('العنوان الوطني', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _field(_city, 'المدينة', 'city'),
        _field(_district, 'الحي', 'district'),
        _field(_street, 'الشارع', 'street'),
        Row(
          children: [
            Expanded(child: _field(_building, 'رقم المبنى', 'building_number', keyboard: TextInputType.number, ltr: true)),
            const SizedBox(width: 12),
            Expanded(child: _field(_postal, 'الرمز البريدي', 'postal_code', keyboard: TextInputType.number, ltr: true)),
          ],
        ),
        const SizedBox(height: 12),
        BusyButton(key: const Key('save-profile'), label: 'حفظ', onPressed: _save),
      ],
    ),
  );
}
