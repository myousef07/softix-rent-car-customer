import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('تسجيل الخروج؟')),
        content: Text(tr('ستحتاج رمز تحقق جديداً للدخول مرة أخرى.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('تراجع'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('خروج'))),
        ],
      ),
    );
    if (sure == true) await ref.read(sessionProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    if (profile == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(tr('حسابي'))),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final p = session.profile ?? profile;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        p.firstName.isEmpty ? tr('؟') : p.firstName.characters.first,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.localMobile,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: tr('الهوية والرخصة'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('رقم الهوية'), p.idNumber ?? '—', ltr: true)),
                        Expanded(
                          child: InfoItem(
                            tr('انتهاء الرخصة'),
                            p.licenseExpiry == null ? '—' : Fmt.date(p.licenseExpiry),
                            valueColor: p.licenseExpiringSoon ? AppColors.danger : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(tr('لتعديل الهوية أو الرخصة أو رقم الجوال راجع أقرب فرع ومعك الأصل.'), style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _Item(icon: Icons.edit_outlined, label: tr('البريد والعنوان الوطني'), onTap: () => context.push('/profile')),
                    const Divider(),
                    _Item(icon: Icons.receipt_long_outlined, label: tr('فواتيري'), onTap: () => context.push('/invoices')),
                    const Divider(),
                    _Item(icon: Icons.location_on_outlined, label: tr('الفروع وأرقام التواصل'), onTap: () => context.push('/branches')),
                    const Divider(),
                    _Item(icon: Icons.support_agent, label: tr('عرض سعر للتأجير الشهري أو للشركات'), onTap: () => context.push('/callback')),
                    const Divider(),
                    _Item(key: const Key('language'), icon: Icons.language, label: AppLanguage.otherName, onTap: AppLanguage.toggle),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: _Item(icon: Icons.logout, label: tr('تسجيل الخروج'), color: AppColors.danger, onTap: () => _signOut(context, ref)),
              ),
              const SizedBox(height: 20),
              Text(
                tr('{0}\nبواسطة SOftiX Rent Car', [AppConfig.companyName]),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? AppColors.primary),
    title: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
    trailing: color == null ? const Icon(Icons.chevron_right) : null,
    onTap: onTap,
  );
}
