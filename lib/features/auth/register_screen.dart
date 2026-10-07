import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

/// What a verified new number carries into registration.
class RegistrationClaim {
  const RegistrationClaim({required this.token, required this.mobile});

  final String token;
  final String mobile;
}

/// First sign-in from a new number: the renter's identity and licence, as the counter would
/// take them. The documents are checked at the branch when the car is handed over.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.claim});

  final RegistrationClaim claim;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static Map<String, String> get idTypes => {'national_id': tr('هوية وطنية'), 'iqama': tr('إقامة'), 'gcc_id': tr('هوية خليجية'), 'passport': tr('جواز سفر'), 'visitor': tr('هوية زائر')};

  static Map<String, String> get nationalities => {
    'SA': tr('السعودية'),
    'EG': tr('مصر'),
    'YE': tr('اليمن'),
    'SY': tr('سوريا'),
    'JO': tr('الأردن'),
    'SD': tr('السودان'),
    'LB': tr('لبنان'),
    'PS': tr('فلسطين'),
    'IQ': tr('العراق'),
    'KW': tr('الكويت'),
    'AE': tr('الإمارات'),
    'BH': tr('البحرين'),
    'QA': tr('قطر'),
    'OM': tr('عُمان'),
    'IN': tr('الهند'),
    'PK': tr('باكستان'),
    'BD': tr('بنغلاديش'),
    'PH': tr('الفلبين'),
    'ID': tr('إندونيسيا'),
    'TR': tr('تركيا'),
    'MA': tr('المغرب'),
    'TN': tr('تونس'),
    'DZ': tr('الجزائر'),
    'US': tr('الولايات المتحدة'),
    'GB': tr('المملكة المتحدة'),
  };

  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _idNumber = TextEditingController();
  final _license = TextEditingController();
  final _email = TextEditingController();
  String _idType = 'national_id';
  String _nationality = 'SA';
  DateTime? _birth;
  DateTime? _licenseExpiry;
  Object? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _idNumber, _license, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: tr('تاريخ الميلاد'),
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 15),
      helpText: tr('تاريخ انتهاء الرخصة'),
    );
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (_birth == null || _licenseExpiry == null) {
      setState(() => _error = 'missing-dates');
      return;
    }

    final date = DateFormat('yyyy-MM-dd', 'en');
    try {
      await ref.read(sessionProvider).register(widget.claim.token, {
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'id_type': _idType,
        'id_number': westernDigits(_idNumber.text).trim(),
        'nationality': _idType == 'national_id' ? 'SA' : _nationality,
        'date_of_birth': date.format(_birth!),
        'license_number': westernDigits(_license.text).trim(),
        'license_expiry_date': date.format(_licenseExpiry!),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      });
      // Signed in: the router takes the renter home.
    } catch (error) {
      if (!mounted) return;
      final failure = ApiException.from(error);
      setState(() => _error = failure);
      if (failure.fieldErrors.containsKey('registration_token')) {
        // The 30 minutes to register ran out: verify the number again.
        showError(context, failure);
        context.go('/login');
      } else if (failure.fieldErrors.isEmpty) {
        showError(context, failure);
      }
    }
  }

  String? _server(String field) => fieldError(_error, field);

  String? _required(String? value) => value == null || value.trim().isEmpty ? tr('مطلوب') : null;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy', 'en');
    final missingDates = _error == 'missing-dates';

    return Scaffold(
      appBar: AppBar(title: Text(tr('حساب جديد'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NoticeBanner(
              tr('أهلاً بك! أكمل بياناتك مرة واحدة فقط. يتحقق الفرع من الهوية والرخصة عند استلام السيارة.'),
              color: AppColors.primary,
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('first_name'),
                    controller: _first,
                    decoration: InputDecoration(labelText: tr('الاسم الأول'), errorText: _server('first_name')),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('last_name'),
                    controller: _last,
                    decoration: InputDecoration(labelText: tr('اسم العائلة'), errorText: _server('last_name')),
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _idType,
              decoration: InputDecoration(labelText: tr('نوع الهوية')),
              items: [for (final e in idTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (value) => setState(() => _idType = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('id_number'),
              controller: _idNumber,
              keyboardType: _idType == 'passport' ? TextInputType.text : TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: tr('رقم الهوية'), errorText: _server('id_number')),
              validator: _required,
            ),
            if (_idType != 'national_id') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _nationality,
                decoration: InputDecoration(labelText: tr('الجنسية')),
                items: [for (final e in nationalities.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (value) => setState(() => _nationality = value!),
              ),
            ],
            const SizedBox(height: 12),
            _DateField(
              key: const Key('birth'),
              label: tr('تاريخ الميلاد'),
              value: _birth == null ? null : date.format(_birth!),
              error: _server('date_of_birth') ?? (missingDates && _birth == null ? tr('مطلوب') : null),
              onTap: _pickBirth,
            ),
            const SizedBox(height: 20),
            Text(
              tr('رخصة القيادة'),
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('license_number'),
              controller: _license,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: tr('رقم الرخصة'), errorText: _server('license_number')),
              validator: _required,
            ),
            const SizedBox(height: 12),
            _DateField(
              key: const Key('license_expiry'),
              label: tr('تاريخ انتهاء الرخصة'),
              value: _licenseExpiry == null ? null : date.format(_licenseExpiry!),
              error: _server('license_expiry_date') ?? (missingDates && _licenseExpiry == null ? tr('مطلوب') : null),
              onTap: _pickExpiry,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: tr('البريد الإلكتروني (اختياري)'), errorText: _server('email')),
            ),
            const SizedBox(height: 24),
            BusyButton(key: const Key('register'), label: tr('إنشاء الحساب'), onPressed: _submit),
            const SizedBox(height: 8),
            Text(
              tr('الجوال: {0}', [widget.claim.mobile]),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({super.key, required this.label, required this.value, required this.onTap, this.error});

  final String label;
  final String? value;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: error, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
      child: Text(value ?? tr('اختر التاريخ'), style: TextStyle(color: value == null ? AppColors.muted : AppColors.text)),
    ),
  );
}
