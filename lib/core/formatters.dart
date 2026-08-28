import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');
final NumberFormat _grouped1dp = NumberFormat('#,##0.0', 'en_US');
final DateFormat _dayMonth = DateFormat('d MMM');
final DateFormat _fullDate = DateFormat('EEE, d MMM yyyy');

/// `Rs 128,400`
String money(num value) => 'Rs ${_grouped.format(value.round())}';

/// `Rs 1.28 L` / `Rs 128.4 k` — for headline tiles where the full number is noise.
String moneyCompact(num value) {
  final v = value.abs();
  if (v >= 10000000) return 'Rs ${(value / 10000000).toStringAsFixed(2)} Cr';
  if (v >= 100000) return 'Rs ${(value / 100000).toStringAsFixed(2)} L';
  if (v >= 1000) return 'Rs ${(value / 1000).toStringAsFixed(1)} k';
  return money(value);
}

String km(num value) => '${_grouped1dp.format(value)} km';

String litres(num value) => '${_grouped1dp.format(value)} L';

String hours(num value) {
  if (value < 1) return '${(value * 60).round()} min';
  final whole = value.floor();
  final mins = ((value - whole) * 60).round();
  return mins == 0 ? '$whole h' : '$whole h $mins m';
}

String durationText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m m';
}

String dayMonth(DateTime d) => _dayMonth.format(d);

String fullDate(DateTime d) => _fullDate.format(d);

String monthName(int month) => DateFormat('MMMM').format(DateTime(2024, month));

String shortMonthName(int month) => DateFormat('MMM').format(DateTime(2024, month));

String plural(int n, String one, String many) => n == 1 ? '$n $one' : '$n $many';
