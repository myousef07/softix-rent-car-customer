import 'package:intl/intl.dart';

import 'config.dart';

/// Western digits, Saudi conventions: 1,035.00 ر.س and day-first dates in Riyadh time.
class Fmt {
  static final _money = NumberFormat('#,##0.00', 'en');
  static final _date = DateFormat('dd/MM/yyyy', 'en');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'en');
  static final _time = DateFormat('HH:mm', 'en');

  static String money(Object? amount) {
    final value = amount is num ? amount : num.tryParse(amount?.toString() ?? '') ?? 0;
    return '${_money.format(value)} ر.س';
  }

  /// API timestamps are UTC; show them in Riyadh time.
  static DateTime? riyadh(String? iso) =>
      iso == null ? null : DateTime.parse(iso).toUtc().add(AppConfig.riyadhOffset);

  static String date(String? iso) => iso == null ? '—' : _date.format(riyadh(iso)!);

  static String dateTime(String? iso) => iso == null ? '—' : _dateTime.format(riyadh(iso)!);

  static String time(String? iso) => iso == null ? '—' : _time.format(riyadh(iso)!);

  /// A wall-clock time picked on the phone, sent as Riyadh time with an explicit offset.
  static String toApi(DateTime riyadhWallClock) {
    final base = DateFormat("yyyy-MM-dd'T'HH:mm:ss", 'en').format(riyadhWallClock);
    return '$base+03:00';
  }

  static DateTime nowInRiyadh() => DateTime.now().toUtc().add(AppConfig.riyadhOffset);

  static String days(int days) => switch (days) {
        1 => 'يوم واحد',
        2 => 'يومان',
        >= 3 && <= 10 => '$days أيام',
        _ => '$days يوماً',
      };

  static const fuelLabels = ['فارغ', '1/8', '2/8', '3/8', '4/8', '5/8', '6/8', '7/8', 'ممتلئ'];
}
