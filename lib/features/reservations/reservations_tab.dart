import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

class ReservationsTab extends ConsumerStatefulWidget {
  const ReservationsTab({super.key});

  @override
  ConsumerState<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends ConsumerState<ReservationsTab> {
  String _scope = 'upcoming';
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    // Booking or cancelling elsewhere refreshes this list too.
    ref.listen(upcomingReservationsProvider, (_, _) => setState(() => _reload++));

    return Scaffold(
      appBar: AppBar(title: const Text('حجوزاتي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'upcoming', label: Text('القادمة')),
                ButtonSegment(value: 'past', label: Text('السابقة')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
          ),
          Expanded(
            child: PagedList<Reservation>(
              filters: (_scope, _reload),
              fetch: (cursor) => ref.read(repositoryProvider).reservations(scope: _scope, cursor: cursor),
              empty: _scope == 'upcoming' ? 'لا توجد حجوزات قادمة. احجز سيارتك من الصفحة الرئيسية.' : 'لا توجد حجوزات سابقة.',
              itemBuilder: (context, r) => ReservationTile(reservation: r),
            ),
          ),
        ],
      ),
    );
  }
}

class ReservationTile extends StatelessWidget {
  const ReservationTile({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => context.push('/reservations/${reservation.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reservation.category?.name ?? 'حجز',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                StatusChip(reservation.statusLabel, color: StatusChip.forReservation(reservation.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${Fmt.dateTime(reservation.pickupAt)} ← ${Fmt.dateTime(reservation.returnAt)}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('${reservation.number} · ${reservation.branch?.name ?? ''}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
                Text(
                  Fmt.money(reservation.total),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
