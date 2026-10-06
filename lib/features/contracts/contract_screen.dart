import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

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
    appBar: AppBar(title: const Text('تفاصيل العقد')),
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
                  'تجاوزت موعد الإعادة ${Fmt.dateTime(c.expectedReturnAt)} وتُحتسب رسوم التأخير. أعد السيارة أو اتصل بالفرع للتمديد.',
                  color: AppColors.danger,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 12),
              ],
              if (balance != null && balance.hasDue) ...[
                NoticeBanner('مستحق عليك ${Fmt.money(balance.due)}', color: AppColors.warning, icon: Icons.account_balance_wallet_outlined),
                const SizedBox(height: 12),
              ],
              SectionCard(
                title: c.car ?? 'السيارة',
                trailing: StatusChip(c.isOverdue ? 'متأخر' : c.statusLabel, color: StatusChip.forContract(c.status, c.isOverdue)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: InfoItem('رقم العقد', c.number, ltr: true)),
                        if (c.plate != null) Expanded(child: InfoItem('اللوحة', c.plate!)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem('الخروج', Fmt.dateTime(c.startAt))),
                        Expanded(
                          child: c.actualReturnAt != null
                              ? InfoItem('العودة', Fmt.dateTime(c.actualReturnAt))
                              : InfoItem('موعد الإعادة', Fmt.dateTime(c.expectedReturnAt), valueColor: c.isOverdue ? AppColors.danger : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem('فرع الخروج', c.branch?.name ?? '—')),
                        Expanded(child: InfoItem('فرع الإعادة', (c.returnBranch ?? c.branch)?.name ?? '—')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem('المدة', Fmt.days(c.days))),
                        Expanded(child: InfoItem('الكيلومترات المشمولة', c.includedKm == null ? 'مفتوحة' : '${c.includedKm} كم')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'البنود',
                child: Column(
                  children: [
                    for (final charge in c.charges) AmountRow(charge.description, Fmt.money(charge.amount)),
                    AmountRow('الضريبة', Fmt.money(c.vat)),
                    const Divider(height: 16),
                    AmountRow('الإجمالي', Fmt.money(c.total), bold: true),
                  ],
                ),
              ),
              if (balance != null) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'الحساب',
                  child: Column(
                    children: [
                      AmountRow('المفوتر', Fmt.money(balance.invoiced)),
                      AmountRow('المدفوع', Fmt.money(balance.paid), color: AppColors.success),
                      const Divider(height: 16),
                      AmountRow('المتبقي', Fmt.money(balance.due), bold: true, color: balance.hasDue ? AppColors.danger : null),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (balance != null && balance.hasDue) ...[
                BusyButton(key: const Key('pay'), icon: Icons.credit_card, label: 'ادفع ${Fmt.money(balance.due)} إلكترونياً', onPressed: () => _pay(c)),
                const SizedBox(height: 8),
              ],
              BusyButton(outlined: true, icon: Icons.picture_as_pdf_outlined, label: 'نسخة العقد (PDF)', onPressed: () => _pdf(c)),
              if (c.branch?.phone != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => callPhone((c.returnBranch ?? c.branch)!.phone ?? c.branch!.phone!),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(c.isOpen ? 'اتصل بالفرع للتمديد أو الاستفسار' : 'اتصل بالفرع'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
