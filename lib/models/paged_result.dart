/// One page of a cursor-paginated list.
class PagedResult<T> {
  PagedResult(this.items, this.nextCursor);

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory PagedResult.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) => PagedResult(
        (json['data'] as List).map((e) => item(Map<String, dynamic>.from(e))).toList(),
        (json['meta'] as Map?)?['next_cursor'] as String?,
      );
}
