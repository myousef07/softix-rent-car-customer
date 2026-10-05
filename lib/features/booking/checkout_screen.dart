import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'booking_draft.dart';

/// The last step: extras, return branch and promo code, the price the renter will pay, and
/// the booking itself.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.draft});

  final CheckoutDraft draft;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _promo = TextEditingController();
  final _notes = TextEditingController();
  final _quantities = <int, int>{};
  int? _returnBranchId;
  String? _appliedPromo;
  String? _promoError;
  late Quote _quote = widget.draft.offer.quote;
  bool _quoting = false;
  int _quoteRequest = 0;

  SearchDraft get _search => widget.draft.search;

  @override
  void dispose() {
    _promo.dispose();
    _notes.dispose();
    super.dispose();
  }

  Map<String, dynamic> _booking() => {
    'branch_id': _search.branch.id,
    'return_branch_id': _returnBranchId ?? _search.branch.id,
    'category_id': widget.draft.offer.category.id,
    'pickup_at': _search.pickupApi,
    'return_at': _search.returnApi,
    'extras': [
      for (final e in _quantities.entries)
        if (e.value > 0) {'id': e.key, 'quantity': e.value},
    ],
    if (_appliedPromo != null) 'promo_code': _appliedPromo,
  };

  /// Prices again whenever an extra or the promo code changes; only the latest answer counts.
  Future<void> _requote() async {
    final request = ++_quoteRequest;
    setState(() => _quoting = true);
    try {
      final quote = await ref.read(repositoryProvider).quote(_booking());
      if (!mounted || request != _quoteRequest) return;
      setState(() => _quote = quote);
    } catch (error) {
      if (!mounted || request != _quoteRequest) return;
      final promo = fieldError(error, 'promo_code');
      if (promo != null && _appliedPromo != null) {
        setState(() {
          _promoError = promo;
          _appliedPromo = null;
        });
        unawaited(_requote());
      } else {
        showError(context, error);
      }
    } finally {
      if (mounted && request == _quoteRequest) setState(() => _quoting = false);
    }
  }

  void _setQuantity(Extra extra, int quantity) {
    setState(() => _quantities[extra.id] = quantity.clamp(0, extra.maxQuantity));
    _requote();
  }

  void _applyPromo() {
    final code = _promo.text.trim().toUpperCase();
    FocusScope.of(context).unfocus();
    setState(() {
      _promoError = null;
      _appliedPromo = code.isEmpty ? null : code;
    });
    _requote();
  }

  Future<void> _book() async {
    try {
      final reservation = await ref.read(repositoryProvider).book({..._booking(), if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim()});
      if (!mounted) return;
      ref.invalidate(upcomingReservationsProvider);
      // Not awaited: the button stops spinning while the confirmation is on screen.
      unawaited(_booked(reservation));
    } catch (error) {
      if (!mounted) return;
      showError(context, ApiException.from(error));
    }
  }

  Future<void> _booked(Reservation reservation) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
        title: const Text('تم تأكيد حجزك'),
        content: Text(
          'رقم الحجز ${reservation.number}\n'
          'الاستلام ${Fmt.dateTime(reservation.pickupAt)} من ${reservation.branch?.name ?? _search.branch.name}.\n'
          'أحضر الهوية والرخصة الأصلية عند الاستلام.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.6),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('عرض الحجز'))],
      ),
    );
    if (!mounted) return;
    context.go('/reservations/${reservation.id}');
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.draft.offer;
    final branches = ref.watch(branchesProvider).value ?? [_search.branch];
    final extras = ref.watch(extrasProvider);
    final profile = ref.watch(sessionProvider).profile;

    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الحجز')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: offer.category.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.modelsLine.isNotEmpty) Text(offer.modelsLine, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: InfoItem('الاستلام', Fmt.dateTime(_search.pickupApi))),
                    Expanded(child: InfoItem('الإعادة', Fmt.dateTime(_search.returnApi))),
                  ],
                ),
                const SizedBox(height: 12),
                InfoItem('فرع الاستلام', _search.branch.name),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _returnBranchId ?? _search.branch.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'فرع الإعادة'),
                  items: [
                    for (final b in branches)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    setState(() => _returnBranchId = id);
                    _requote();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          extras.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : SectionCard(
                    title: 'الإضافات',
                    child: Column(
                      children: [
                        for (final extra in list) _ExtraRow(extra: extra, quantity: _quantities[extra.id] ?? 0, onChanged: (q) => _setQuantity(extra, q)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'رمز الخصم',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('promo'),
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'إن وُجد',
                      errorText: _promoError,
                      helperText: _appliedPromo != null && _quote.hasDiscount ? 'تم تطبيق الخصم ✓' : null,
                    ),
                    onSubmitted: (_) => _applyPromo(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: OutlinedButton(onPressed: _applyPromo, child: const Text('تطبيق')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'ملاحظات للفرع',
            child: TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(hintText: 'مثلاً: موعد وصول الرحلة، كرسي أطفال…'),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'السعر',
            trailing: _quoting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            child: Column(
              children: [
                for (final line in _quote.lines) AmountRow(line.description, Fmt.money(line.amount)),
                if (_quote.hasDiscount) AmountRow('الخصم', '- ${Fmt.money(_quote.discount)}', color: AppColors.success),
                AmountRow('ضريبة القيمة المضافة 15%', Fmt.money(_quote.vat)),
                const Divider(height: 16),
                AmountRow('الإجمالي', Fmt.money(_quote.total), bold: true),
                const SizedBox(height: 8),
                Text(
                  'يُدفع عند الاستلام في الفرع، مع تأمين مسترد ${Fmt.money(_quote.deposit)}.'
                  '${_quote.includedKm != null ? ' تشمل الأجرة ${_quote.includedKm} كم، وتُحسب الزيادة حسب سعر الفئة.' : ''}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          if (profile?.licenseExpiringSoon ?? false) ...[
            const SizedBox(height: 12),
            NoticeBanner('تنبيه: رخصتك تنتهي في ${Fmt.date(profile!.licenseExpiry)}. لا تُسلَّم السيارة برخصة منتهية.'),
          ],
          const SizedBox(height: 20),
          BusyButton(key: const Key('confirm-booking'), label: 'تأكيد الحجز · ${Fmt.money(_quote.total)}', onPressed: _quoting ? null : _book),
          const SizedBox(height: 8),
          const Text(
            'يمكنك إلغاء الحجز مجاناً من التطبيق حتى ساعتين قبل موعد الاستلام.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.extra, required this.quantity, required this.onChanged});

  final Extra extra;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                extra.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('${Fmt.money(extra.price)} ${extra.unit}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        if (extra.maxQuantity <= 1)
          Switch(value: quantity > 0, onChanged: (on) => onChanged(on ? 1 : 0))
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(
                width: 20,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(onPressed: quantity < extra.maxQuantity ? () => onChanged(quantity + 1) : null, icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
      ],
    ),
  );
}
