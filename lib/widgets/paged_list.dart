import 'package:flutter/material.dart';

import '../models/paged_result.dart';
import 'common.dart';
import '../core/i18n.dart';

/// Pull-to-refresh list over a cursor-paginated endpoint; loads the next page near the end.
class PagedList<T> extends StatefulWidget {
  const PagedList({super.key, required this.fetch, required this.itemBuilder, this.filters, this.empty, this.header});

  final Future<PagedResult<T>> Function(String? cursor) fetch;

  /// The list reloads from the first page whenever this value changes (search text, tab, branch).
  final Object? filters;
  final Widget Function(BuildContext context, T item) itemBuilder;
  /// Shown when there is nothing to list; «No results» by default.
  final String? empty;
  final Widget? header;

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final _items = <T>[];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant PagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) refresh();
  }

  Future<void> refresh() async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _error = null;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await widget.fetch(_cursor);
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _error != null) return ErrorView(_error!, onRetry: refresh);
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());

    final headerCount = widget.header == null ? 0 : 1;

    return RefreshIndicator(
      onRefresh: refresh,
      child: _items.isEmpty
          ? ListView(children: [?widget.header, EmptyState(widget.empty ?? tr('لا توجد نتائج.'))])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: headerCount + _items.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (headerCount == 1 && index == 0) return widget.header!;
                final i = index - headerCount;
                if (i >= _items.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                return widget.itemBuilder(context, _items[i]);
              },
            ),
    );
  }
}
