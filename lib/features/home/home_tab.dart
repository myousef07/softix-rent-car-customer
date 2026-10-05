import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../booking/booking_draft.dart';

/// Home: the car the renter has now, the next pickup, and the booking search.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key, required this.onOpenTab});

  final void Function(int tab) onOpenTab;

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  Branch? _branch;
  late DateTime _pickup;
  late DateTime _return;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tomorrow = Fmt.nowInRiyadh().add(const Duration(days: 1));
    _pickup = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
    _return = _pickup.add(const Duration(days: 3));
  }

  Future<void> _refresh() async {
    ref.invalidate(openContractsProvider);
    ref.invalidate(upcomingReservationsProvider);
    ref.invalidate(branchesProvider);
    await ref.read(sessionProvider).reloadProfile().catchError((_) {});
  }

  Future<DateTime?> _pick(DateTime current, {required DateTime first}) async {
    final day = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: first.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return null;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return null;

    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _pickPickup() async {
    final picked = await _pick(_pickup, first: Fmt.nowInRiyadh());
    if (picked == null) return;
    setState(() {
      final length = _return.difference(_pickup);
      _pickup = picked;
      if (!_return.isAfter(_pickup)) _return = _pickup.add(length.isNegative || length == Duration.zero ? const Duration(days: 1) : length);
      _error = null;
    });
  }

  Future<void> _pickReturn() async {
    final picked = await _pick(_return, first: _pickup);
    if (picked == null) return;
    setState(() {
      _return = picked;
      _error = null;
    });
  }

  void _search(List<Branch> branches) {
    final branch = _branch ?? (branches.length == 1 ? branches.first : null);
    if (branch == null) return setState(() => _error = 'اختر فرع الاستلام.');
    if (!_pickup.isAfter(Fmt.nowInRiyadh().add(const Duration(minutes: 30)))) {
      return setState(() => _error = 'اختر وقت استلام بعد نصف ساعة من الآن على الأقل.');
    }
    if (!_return.isAfter(_pickup)) return setState(() => _error = 'موعد الإعادة يجب أن يكون بعد الاستلام.');

    setState(() => _error = null);
    context.push(
      '/book/offers',
      extra: SearchDraft(branch: branch, pickup: _pickup, returnAt: _return),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).profile;
    final branches = ref.watch(branchesProvider);
    final contracts = ref.watch(openContractsProvider);
    final upcoming = ref.watch(upcomingReservationsProvider);
    final days = (_return.difference(_pickup).inMinutes / (24 * 60)).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/softix-logo.png', height: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(AppConfig.companyName, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'أهلاً ${profile?.firstName ?? ''}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            if (profile?.licenseExpiringSoon ?? false) ...[
              NoticeBanner(
                'رخصة قيادتك تنتهي في ${Fmt.date(profile!.licenseExpiry)}. جدّدها قبل الاستلام، فالفرع لا يسلّم السيارة برخصة منتهية.',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),
            ],
            for (final contract in contracts.value ?? const <Contract>[]) ...[_CurrentRental(contract: contract), const SizedBox(height: 12)],
            if ((upcoming.value ?? const []).isNotEmpty) ...[_NextPickup(reservation: upcoming.value!.first), const SizedBox(height: 12)],
            SectionCard(
              title: 'احجز سيارة',
              child: branches.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => ErrorView(error, onRetry: () => ref.invalidate(branchesProvider)),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      key: const Key('branch'),
                      initialValue: (_branch ?? (list.length == 1 ? list.first : null))?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'فرع الاستلام', prefixIcon: Icon(Icons.storefront_outlined)),
                      items: [
                        for (final b in list)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text(b.place.isEmpty ? b.name : '${b.name} — ${b.place}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) => setState(() => _branch = list.firstWhere((b) => b.id == id)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _WhenField(key: const Key('pickup'), label: 'الاستلام', value: Fmt.dayTime(_pickup), onTap: _pickPickup),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _WhenField(key: const Key('return'), label: 'الإعادة', value: Fmt.dayTime(_return), onTap: _pickReturn),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(days > 0 ? 'مدة الإيجار: ${Fmt.days(days)}' : '', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.danger))],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('search'),
                      onPressed: list.isEmpty ? null : () => _search(list),
                      icon: const Icon(Icons.search),
                      label: const Text('اعرض السيارات المتاحة'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Shortcut(icon: Icons.receipt_long_outlined, label: 'فواتيري', onTap: () => context.push('/invoices')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Shortcut(icon: Icons.location_on_outlined, label: 'الفروع', onTap: () => context.push('/branches')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Shortcut(icon: Icons.support_agent, label: 'عرض سعر خاص', onTap: () => context.push('/callback')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WhenField extends StatelessWidget {
  const _WhenField({super.key, required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The car out with the renter now: when it's due back and anything left to pay.
class _CurrentRental extends StatelessWidget {
  const _CurrentRental({required this.contract});

  final Contract contract;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primarySoft,
    child: InkWell(
      onTap: () => context.push('/contracts/${contract.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'سيارتك الحالية',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                StatusChip(contract.isOverdue ? 'متأخر' : contract.statusLabel, color: StatusChip.forContract(contract.status, contract.isOverdue)),
              ],
            ),
            const SizedBox(height: 10),
            Text([contract.car, contract.plate].whereType<String>().join(' · '), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'موعد الإعادة: ${Fmt.dateTime(contract.expectedReturnAt)}${contract.returnBranch != null ? ' — ${contract.returnBranch!.name}' : ''}',
              style: TextStyle(color: contract.isOverdue ? AppColors.danger : AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NextPickup extends StatelessWidget {
  const _NextPickup({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: () => context.push('/reservations/${reservation.id}'),
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.event_available, color: AppColors.primary),
      ),
      title: Text('حجزك القادم: ${reservation.category?.name ?? reservation.number}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${Fmt.dateTime(reservation.pickupAt)} — ${reservation.branch?.name ?? ''}'),
      trailing: const Icon(Icons.chevron_left),
    ),
  );
}
