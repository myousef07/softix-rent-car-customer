import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/files.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../self_service/self_service_screen.dart';
import '../../core/i18n.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  late Future<Reservation> _reservation = ref.read(repositoryProvider).reservation(widget.id);

  void _reload() => setState(() {
    _reservation = ref.read(repositoryProvider).reservation(widget.id);
  });

  Future<void> _cancel(Reservation r) async {
    // The reason, or null when the renter changes their mind.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(number: r.number),
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(repositoryProvider).cancelReservation(r.id, reason.isEmpty ? null : reason);
      if (!mounted) return;
      ref.invalidate(upcomingReservationsProvider);
      showSuccess(context, tr('تم إلغاء الحجز.'));
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('تفاصيل الحجز'))),
    body: FutureBuilder<Reservation>(
      future: _reservation,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(snapshot.error!, onRetry: _reload);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final r = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (r.status == 'confirmed') SelfServiceCard(key: ValueKey('pickup-${r.id}'), pickup: true, id: r.id),
              SectionCard(
                title: r.category?.name ?? tr('الحجز'),
                trailing: StatusChip(r.statusLabel, color: StatusChip.forReservation(r.status)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoItem(tr('رقم الحجز'), r.number, ltr: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('الاستلام'), Fmt.dateTime(r.pickupAt))),
                        Expanded(child: InfoItem(tr('الإعادة'), Fmt.dateTime(r.returnAt))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: InfoItem(tr('فرع الاستلام'), r.branch?.name ?? '—')),
                        Expanded(child: InfoItem(tr('فرع الإعادة'), (r.returnBranch ?? r.branch)?.name ?? '—')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InfoItem(tr('المدة'), Fmt.days(r.days)),
                    if (r.extras.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InfoItem(tr('الإضافات'), r.extras.map((e) => e.quantity > 1 ? '${e.name} × ${e.quantity}' : e.name).join(tr('، '))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: tr('المبالغ'),
                child: Column(
                  children: [
                    AmountRow(tr('قبل الضريبة'), Fmt.money(r.subtotal)),
                    if ((double.tryParse(r.discount) ?? 0) > 0) AmountRow(tr('الخصم'), '- ${Fmt.money(r.discount)}', color: AppColors.success),
                    AmountRow(tr('الضريبة'), Fmt.money(r.vat)),
                    const Divider(height: 16),
                    AmountRow(tr('الإجمالي'), Fmt.money(r.total), bold: true),
                    AmountRow(tr('التأمين المسترد (عند الاستلام)'), Fmt.money(r.deposit)),
                  ],
                ),
              ),
              if (r.isActive) ...[
                const SizedBox(height: 12),
                NoticeBanner(tr('أحضر الهوية ورخصة القيادة الأصلية عند الاستلام.'), color: AppColors.primary, icon: Icons.badge_outlined),
              ],
              const SizedBox(height: 16),
              if (r.contractId != null)
                FilledButton.icon(
                  onPressed: () => context.push('/contracts/${r.contractId}'),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(tr('عرض العقد')),
                ),
              if (r.branch?.phone != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => callPhone(r.branch!.phone!), icon: const Icon(Icons.call_outlined), label: Text(tr('اتصل بالفرع'))),
              ],
              if (r.branch?.latitude != null && r.branch?.longitude != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => openMap(r.branch!.latitude!, r.branch!.longitude!),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(tr('موقع الفرع')),
                ),
              ],
              if (r.isActive) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('cancel-reservation'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => _cancel(r),
                  child: Text(tr('إلغاء الحجز')),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.number});

  final String number;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('إلغاء الحجز؟')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('سيُلغى الحجز {0}.', [widget.number])),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLength: 255,
          decoration: InputDecoration(labelText: tr('السبب (اختياري)')),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('تراجع'))),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.pop(context, _reason.text.trim()),
        child: Text(tr('إلغاء الحجز')),
      ),
    ],
  );
}
