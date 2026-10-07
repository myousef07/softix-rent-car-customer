import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'booking_draft.dart';
import '../../core/i18n.dart';

/// Every category at the branch for the chosen dates, with its full price.
class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key, required this.search});

  final SearchDraft search;

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  late Future<List<Offer>> _offers = _load();

  Future<List<Offer>> _load() =>
      ref.read(repositoryProvider).search(branchId: widget.search.branch.id, pickupAt: widget.search.pickupApi, returnAt: widget.search.returnApi);

  @override
  Widget build(BuildContext context) {
    final s = widget.search;

    return Scaffold(
      appBar: AppBar(title: Text(tr('اختر الفئة'))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              '${s.branch.name} · ${Fmt.dateTime(s.pickupApi)} ← ${Fmt.dateTime(s.returnApi)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Offer>>(
              future: _offers,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    snapshot.error!,
                    onRetry: () => setState(() {
                      _offers = _load();
                    }),
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final offers = [...snapshot.data!]..sort((a, b) => (a.available == b.available) ? 0 : (a.available ? -1 : 1));
                if (offers.isEmpty) return EmptyState(tr('لا توجد فئات متاحة في هذا الفرع.'), icon: Icons.car_rental);

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: offers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _OfferCard(
                    offer: offers[i],
                    onTap: offers[i].available
                        ? () => context.push(
                            '/book/checkout',
                            extra: CheckoutDraft(search: s, offer: offers[i]),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, this.onTap});

  final Offer offer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final q = offer.quote;
    final muted = !offer.available;

    return Opacity(
      opacity: muted ? 0.55 : 1,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.category.imageUrl != null) ...[CarImage(offer.category.imageUrl, height: 140), const SizedBox(height: 12)],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (offer.category.imageUrl == null) ...[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_car_filled, color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
                          ),
                          if (offer.modelsLine.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              offer.modelsLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (offer.seats != null) _Spec(Icons.event_seat_outlined, tr('{0} مقاعد', [offer.seats])),
                    _Spec(Icons.speed, q.includedKm == null ? tr('كيلومترات مفتوحة') : tr('{0} كم مشمولة', [q.includedKm])),
                    _Spec(Icons.shield_outlined, tr('تأمين {0} مسترد', [Fmt.money(q.deposit)])),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: offer.available
                          ? Text(tr('{0} / يوم قبل الضريبة', [Fmt.money(q.perDay.toStringAsFixed(2))]), style: const TextStyle(color: AppColors.muted, fontSize: 12))
                          : Text(
                              tr('غير متاحة في هذه الفترة'),
                              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                            ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Fmt.money(q.total),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                        ),
                        Text(tr('الإجمالي لـ {0} شامل الضريبة', [Fmt.days(q.days)]), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text)),
    ],
  );
}
