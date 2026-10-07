import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = AppColors.muted});

  final String label;
  final Color color;

  static Color forContract(String status, bool overdue) => overdue
      ? AppColors.danger
      : switch (status) {
          'open' => AppColors.primary,
          'closed' => AppColors.success,
          _ => AppColors.muted,
        };

  static Color forReservation(String status) => switch (status) {
    'confirmed' => AppColors.primary,
    'pending' => AppColors.warning,
    'converted' => AppColors.success,
    'cancelled' || 'no_show' => AppColors.danger,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

/// A label on top of a value, the building block of detail screens.
class InfoItem extends StatelessWidget {
  const InfoItem(this.label, this.value, {super.key, this.valueColor, this.ltr = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool ltr;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 2),
      Text(
        value,
        textDirection: ltr ? TextDirection.ltr : null,
        style: TextStyle(color: valueColor ?? AppColors.text, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing});

  final String? title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(ApiException.from(error).message, textAlign: TextAlign.center),
          if (onRetry != null) ...[const SizedBox(height: 12), TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة'))],
        ],
      ),
    ),
  );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(ApiException.from(error).message), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
}

/// A button that shows a spinner and ignores taps while its action runs.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false});

  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final child = _busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return widget.outlined ? OutlinedButton(onPressed: onPressed, child: child) : FilledButton(onPressed: onPressed, child: child);
  }
}

/// A notice inside a screen: a warning about the licence, an overdue car, an amount due.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.message, {super.key, this.color = AppColors.warning, this.icon = Icons.info_outline, this.action});

  final String message;
  final Color color;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// A label and an amount on one line, for price breakdowns.
class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.amount, {super.key, this.bold = false, this.color});

  final String label;
  final String amount;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color ?? (bold ? AppColors.ink : AppColors.text),
      fontSize: bold ? 16 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: style.copyWith(color: color ?? (bold ? AppColors.ink : AppColors.muted))),
          ),
          Text(amount, style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

/// Arabic-Indic digits typed on an Arabic keyboard become the Western digits the API expects.
String westernDigits(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final out = StringBuffer();
  for (final char in input.split('')) {
    final e = eastern.indexOf(char);
    final p = persian.indexOf(char);
    out.write(e >= 0 ? '$e' : (p >= 0 ? '$p' : char));
  }
  return out.toString();
}

/// 05XXXXXXXX, with or without +966 / 966 / spaces; null when it is not a Saudi mobile.
String? saudiMobile(String input) {
  var digits = westernDigits(input).replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('+966')) digits = '0${digits.substring(4)}';
  if (digits.startsWith('00966')) digits = '0${digits.substring(5)}';
  if (digits.startsWith('966')) digits = '0${digits.substring(3)}';
  if (digits.startsWith('5') && digits.length == 9) digits = '0$digits';
  return RegExp(r'^05\d{8}$').hasMatch(digits) ? digits : null;
}

/// The server's message for one field of a failed form, to show under that field.
String? fieldError(Object? error, String field) {
  if (error is! ApiException) return null;
  final messages = error.fieldErrors[field];
  return messages == null || messages.isEmpty ? null : messages.first;
}

/// A category's car photo, or the car icon while it loads, when there is none or it fails.
class CarImage extends StatelessWidget {
  const CarImage(this.url, {super.key, this.height = 150});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.directions_car_filled, color: AppColors.primary, size: height * .35),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }
}
