import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';
import '../../core/i18n.dart';

/// Sign in with the mobile number and the SMS code; a number the company doesn't know yet
/// goes on to registration.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _resendSeconds = 60;

  final _mobile = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _mobileError;
  String? _codeError;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _mobile.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _wait <= 1) {
        timer.cancel();
        if (mounted) setState(() => _wait = 0);
        return;
      }
      setState(() => _wait--);
    });
  }

  Future<void> _sendCode() async {
    final mobile = saudiMobile(_mobile.text);
    if (mobile == null) {
      setState(() => _mobileError = tr('أدخل رقم جوال سعودي صحيح، مثل 0551234567.'));
      return;
    }

    setState(() => _mobileError = null);
    try {
      await ref.read(sessionProvider).requestCode(mobile);
      if (!mounted) return;
      setState(() {
        _sentTo = mobile;
        _code.clear();
        _codeError = null;
      });
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() => _mobileError = fieldError(error, 'mobile'));
      if (_mobileError == null) showError(context, error);
    }
  }

  Future<void> _verify() async {
    final code = westernDigits(_code.text).trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _codeError = tr('الرمز 6 أرقام.'));
      return;
    }

    setState(() => _codeError = null);
    try {
      final result = await ref.read(sessionProvider).verify(_sentTo!, code);
      if (!mounted) return;
      // Signed in: the router moves on by itself. A new number registers first.
      if (result.isNew) {
        context.go(
          '/register',
          extra: RegistrationClaim(token: result.registrationToken!, mobile: _sentTo!),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _codeError = fieldError(error, 'code'));
      if (_codeError == null) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeStep = _sentTo != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const Key('language'),
                onPressed: AppLanguage.toggle,
                icon: const Icon(Icons.language, size: 18),
                label: Text(AppLanguage.otherName),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Image.asset('assets/images/softix-logo.png', height: 64)),
            const SizedBox(height: 16),
            Text(
              AppConfig.companyName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              tr('احجز سيارتك وتابع عقودك وفواتيرك من جوالك'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 36),
            if (!codeStep) ...[
              Text(tr('رقم الجوال'), style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('mobile'),
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [LengthLimitingTextInputFormatter(14)],
                decoration: InputDecoration(hintText: '05XXXXXXXX', errorText: _mobileError, prefixIcon: const Icon(Icons.phone_iphone)),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 20),
              BusyButton(key: const Key('send-code'), label: tr('أرسل رمز التحقق'), onPressed: _sendCode),
            ] else ...[
              Text(
                tr('أرسلنا رمزاً من 6 أرقام إلى'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                _sentTo!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('code'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [LengthLimitingTextInputFormatter(6)],
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
                decoration: InputDecoration(hintText: '••••••', errorText: _codeError),
                onChanged: (value) {
                  if (westernDigits(value).length == 6) _verify();
                },
              ),
              const SizedBox(height: 20),
              BusyButton(key: const Key('verify'), label: tr('دخول'), onPressed: _verify),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      setState(() {
                        _sentTo = null;
                        _wait = 0;
                      });
                    },
                    child: Text(tr('تغيير الرقم')),
                  ),
                  TextButton(onPressed: _wait > 0 ? null : _sendCode, child: Text(_wait > 0 ? tr('إعادة الإرسال بعد {0} ث', [_wait]) : tr('إعادة إرسال الرمز'))),
                ],
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/callback'),
              icon: const Icon(Icons.support_agent),
              label: Text(tr('اطلب عرض سعر أو اتصالاً من فريقنا')),
            ),
          ],
        ),
      ),
    );
  }
}
