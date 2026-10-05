import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

class ContractsTab extends ConsumerStatefulWidget {
  const ContractsTab({super.key});

  @override
  ConsumerState<ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends ConsumerState<ContractsTab> {
  String _scope = 'open';
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen(openContractsProvider, (_, _) => setState(() => _reload++));

    return Scaffold(
      appBar: AppBar(title: const Text('عقودي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('السارية')),
                ButtonSegment(value: 'closed', label: Text('المنتهية')),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
          ),
          Expanded(
            child: PagedList<Contract>(
              filters: (_scope, _reload),
              fetch: (cursor) => ref.read(repositoryProvider).contracts(scope: _scope, cursor: cursor),
              empty: _scope == 'open' ? 'لا توجد عقود سارية.' : 'لا توجد عقود سابقة.',
              itemBuilder: (context, c) => _ContractTile(contract: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  const _ContractTile({required this.contract});

  final Contract contract;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => context.push('/contracts/${contract.id}'),
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
                    contract.car ?? contract.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                StatusChip(contract.isOverdue ? 'متأخر' : contract.statusLabel, color: StatusChip.forContract(contract.status, contract.isOverdue)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${Fmt.date(contract.startAt)} ← ${Fmt.date(contract.actualReturnAt ?? contract.expectedReturnAt)}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text([contract.number, contract.plate].whereType<String>().join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
                Text(
                  Fmt.money(contract.total),
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
