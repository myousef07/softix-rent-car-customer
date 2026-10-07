import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../self_service/self_service_screen.dart';
import '../../core/i18n.dart';

/// One rental: the car, the dates, what was charged, what is still due, and the way to pay it.
class ContractScreen extends ConsumerStatefulWidget {
  const ContractScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends ConsumerState<ContractScreen> {
  late Future<Contract> _contract = _load();
  late final AppLifecycleListener _lifecycle;
  bool _paying = false;

  Future<Contract> _load() => ref.read(repositoryProvider).contract(widget.id);

  void _reload() => setState(() {
    _contract = _load();
  });

  @override
  void initState() {
    super.initState();
    // Back from the payment page: show the new balance.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_paying && mounted) {
          _paying = false;
          _reload();
          ref.invalidate(openContractsProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _pay(Contract c) async {
    try {
      final page = await ref.read(repositoryProvider).payContract(c.id);
      _paying = true;
      await openPaymentPage(page.url);
    } catch (error) {
      _paying = false;
      if (mounted) showError(context, error);
    }
  }

  Future<void> _pdf(Contract c) async {
    try {
      await openPdf(context, () => ref.read(repositoryProvider).contractPdf(c.id), c.number);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('تفاصيل العقد'))),
    body: FutureBuilder<Contract>(
      future: _contract,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(snapshot.error!, onRetry: _reload);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final c = snapshot.data!;
        final balance = c.balance;

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (c.isOverdue) ...[
                NoticeBanner(
                  tr('تجاوزت موعد الإعادة {0} وتُحتسب رسوم التأخير. أعد السيارة أو اتصل بالفرع للتمديد.', [Fmt.dateTime(c.expectedReturnAt)]),
                  color: AppColors.danger,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 12),
              ],
              if (balance != null && balance.hasDue) ...[
                NoticeBanner(tr('مستحق عليك {0}', [Fmt.money(balance.due)]), color: AppColors.warning, icon: Icons.account_balance_wallet_outlined),
                const SizedBox(height: 12),
              ],
              SectionCard(
                title: c.car ?? tr('السيارة'),
                trailing: StatusChip(c.isOverdue ? tr('متأخر') : c.statusLabel, color: StatusChip.forContract(c.status, c.isOverdue)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('رقم العقد'), c.number, ltr: true)),
                        if (c.plate != null) Expanded(child: InfoItem(tr('اللوحة'), c.plate!)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('الخروج'), Fmt.dateTime(c.startAt))),
                        Expanded(
                          child: c.actualReturnAt != null
                              ? InfoItem(tr('العودة'), Fmt.dateTime(c.actualReturnAt))
                              : InfoItem(tr('موعد الإعادة'), Fmt.dateTime(c.expectedReturnAt), valueColor: c.isOverdue ? AppColors.danger : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('فرع الخروج'), c.branch?.name ?? '—')),
                        Expanded(child: InfoItem(tr('فرع الإعادة'), (c.returnBranch ?? c.branch)?.name ?? '—')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('المدة'), Fmt.days(c.days))),
                        Expanded(child: InfoItem(tr('الكيلومترات المشمولة'), c.includedKm == null ? tr('مفتوحة') : tr('{0} كم', [c.includedKm]))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: tr('البنود'),
                child: Column(
                  children: [
                    for (final charge in c.charges) AmountRow(charge.description, Fmt.money(charge.amount)),
                    AmountRow(tr('الضريبة'), Fmt.money(c.vat)),
                    const Divider(height: 16),
                    AmountRow(tr('الإجمالي'), Fmt.money(c.total), bold: true),
                  ],
                ),
              ),
              if (balance != null) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: tr('الحساب'),
                  child: Column(
                    children: [
                      AmountRow(tr('المفوتر'), Fmt.money(balance.invoiced)),
                      AmountRow(tr('المدفوع'), Fmt.money(balance.paid), color: AppColors.success),
                      const Divider(height: 16),
                      AmountRow(tr('المتبقي'), Fmt.money(balance.due), bold: true, color: balance.hasDue ? AppColors.danger : null),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (balance != null && balance.hasDue) ...[
                BusyButton(key: const Key('pay'), icon: Icons.credit_card, label: tr('ادفع {0} إلكترونياً', [Fmt.money(balance.due)]), onPressed: () => _pay(c)),
                const SizedBox(height: 8),
              ],
              BusyButton(outlined: true, icon: Icons.picture_as_pdf_outlined, label: tr('نسخة العقد (PDF)'), onPressed: () => _pdf(c)),
              if (c.isOpen) ...[const SizedBox(height: 12), SelfServiceCard(key: ValueKey('return-${c.id}'), pickup: false, id: c.id)],
              if (c.branch?.phone != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => callPhone((c.returnBranch ?? c.branch)!.phone ?? c.branch!.phone!),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(c.isOpen ? tr('اتصل بالفرع للتمديد أو الاستفسار') : tr('اتصل بالفرع')),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
