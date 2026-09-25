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
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
          Text(value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(color: valueColor ?? AppColors.text, fontWeight: FontWeight.w600)),
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
                Row(children: [
                  Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
                  ?trailing,
                ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(ApiException.from(error).message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ]),
        ),
      );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(ApiException.from(error).message),
    backgroundColor: AppColors.danger,
    behavior: SnackBarBehavior.floating,
  ));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: AppColors.success,
    behavior: SnackBarBehavior.floating,
  ));
}
