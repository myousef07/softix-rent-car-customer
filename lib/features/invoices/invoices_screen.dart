import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

/// Tax invoices and credit notes; tapping one opens the PDF with its ZATCA QR code.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('فواتيري')),
    body: PagedList<Invoice>(
      fetch: (cursor) => ref.read(repositoryProvider).invoices(cursor: cursor),
      empty: 'لا توجد فواتير بعد.',
      itemBuilder: (context, invoice) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(invoice.isCreditNote ? Icons.undo : Icons.receipt_long, color: AppColors.primary),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  invoice.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              StatusChip(invoice.statusLabel, color: (double.tryParse(invoice.due) ?? 0) > 0 ? AppColors.warning : AppColors.success),
            ],
          ),
          subtitle: Text(
            [
              if (invoice.isCreditNote) 'إشعار دائن',
              Fmt.date(invoice.issuedAt),
              if (invoice.contractNumber != null) 'عقد ${invoice.contractNumber}',
              if ((double.tryParse(invoice.due) ?? 0) > 0) 'المتبقي ${Fmt.money(invoice.due)}',
            ].join(' · '),
          ),
          trailing: Text(
            Fmt.money(invoice.total),
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onTap: () async {
            try {
              await openPdf(context, () => ref.read(repositoryProvider).invoicePdf(invoice.id), invoice.number);
            } catch (error) {
              if (context.mounted) showError(context, error);
            }
          },
        ),
      ),
    ),
  );
}
