import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('الفروع'))),
      body: branches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error, onRetry: () => ref.invalidate(branchesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(tr('لا توجد فروع.'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final b = list[i];
                  return SectionCard(
                    title: b.name,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ([b.address, b.place].any((s) => s != null && s.isNotEmpty))
                          Text([b.address, b.place].whereType<String>().where((s) => s.isNotEmpty).join(' — '), style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (b.phone != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => callPhone(b.phone!),
                                  icon: const Icon(Icons.call_outlined, size: 18),
                                  label: Text(b.phone!, textDirection: TextDirection.ltr),
                                ),
                              ),
                            if (b.phone != null && b.latitude != null) const SizedBox(width: 8),
                            if (b.latitude != null && b.longitude != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => openMap(b.latitude!, b.longitude!),
                                  icon: const Icon(Icons.map_outlined, size: 18),
                                  label: Text(tr('الموقع')),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
