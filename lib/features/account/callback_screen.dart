import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

/// «Send me a quote / call me back», with or without an account: monthly rentals, leases and
/// company accounts are priced by the sales team.
class CallbackScreen extends ConsumerStatefulWidget {
  const CallbackScreen({super.key});

  @override
  ConsumerState<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends ConsumerState<CallbackScreen> {
  static Map<String, String> get interests => {
    'daily': tr('إيجار يومي'),
    'monthly': tr('إيجار شهري'),
    'lease': tr('تأجير طويل / تمليك'),
    'corporate': tr('حساب شركة'),
    'delivery': tr('توصيل السيارة'),
    'other': tr('أخرى'),
  };

  late final _profile = ref.read(sessionProvider).profile;
  late final _name = TextEditingController(text: _profile?.name);
  late final _mobile = TextEditingController(text: _profile?.localMobile);
  final _company = TextEditingController();
  final _days = TextEditingController();
  final _message = TextEditingController();
  String _interest = 'monthly';
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _mobile, _company, _days, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final mobile = saudiMobile(_mobile.text);
    if (_name.text.trim().isEmpty || mobile == null) {
      setState(
        () => _error = ApiException(
          '',
          fieldErrors: {
            if (_name.text.trim().isEmpty) 'name': [tr('اكتب اسمك.')],
            if (mobile == null) 'mobile': [tr('أدخل رقم جوال سعودي صحيح.')],
          },
        ),
      );
      return;
    }

    setState(() => _error = null);
    try {
      final reference = await ref.read(repositoryProvider).requestCallback({
        'name': _name.text.trim(),
        'mobile': mobile,
        'interest': _interest,
        if (_company.text.trim().isNotEmpty) 'company_name': _company.text.trim(),
        if (int.tryParse(westernDigits(_days.text)) != null) 'days': int.parse(westernDigits(_days.text)),
        if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
      });
      if (!mounted) return;
      unawaited(_sent(reference));
    } catch (error) {
      if (!mounted) return;
      final failure = ApiException.from(error);
      setState(() => _error = failure);
      if (failure.fieldErrors.keys.every((k) => !const ['name', 'mobile', 'days', 'message'].contains(k))) showError(context, failure);
    }
  }

  Future<void> _sent(String reference) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
        title: Text(tr('وصل طلبك')),
        content: Text(tr('سيتواصل معك فريقنا قريباً.{0}', [reference.isNotEmpty ? tr('\nرقم الطلب: {0}', [reference]) : '']), textAlign: TextAlign.center),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('تم')))],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('اطلب عرض سعر'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('اترك بياناتك ويتصل بك فريق المبيعات بأفضل سعر.'), style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in interests.entries)
              ChoiceChip(label: Text(e.value), selected: _interest == e.key, onSelected: (_) => setState(() => _interest = e.key)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('lead-name'),
          controller: _name,
          decoration: InputDecoration(labelText: tr('الاسم'), errorText: fieldError(_error, 'name')),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('lead-mobile'),
          controller: _mobile,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: tr('الجوال'), hintText: '05XXXXXXXX', errorText: fieldError(_error, 'mobile')),
        ),
        if (_interest == 'corporate' || _interest == 'lease') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _company,
            decoration: InputDecoration(labelText: tr('اسم المنشأة (اختياري)')),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _days,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr('المدة بالأيام (اختياري)'), errorText: fieldError(_error, 'days')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          maxLines: 3,
          maxLength: 1000,
          decoration: InputDecoration(labelText: tr('تفاصيل (اختياري)'), errorText: fieldError(_error, 'message')),
        ),
        const SizedBox(height: 12),
        BusyButton(key: const Key('send-lead'), label: tr('أرسل الطلب'), onPressed: _send),
      ],
    ),
  );
}
