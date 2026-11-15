import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String formatRupiah(num value) =>
    _rupiah.format(value).replaceFirst('Rp', 'Rp ');

String formatCompactRupiah(num value) {
  final absolute = value.abs();
  final sign = value < 0 ? '-' : '';
  if (absolute >= 1000000000) {
    return '$sign${(absolute / 1000000000).toStringAsFixed(1)} M';
  }
  if (absolute >= 1000000) {
    return '$sign${(absolute / 1000000).toStringAsFixed(1)} jt';
  }
  if (absolute >= 1000) {
    return '$sign${(absolute / 1000).toStringAsFixed(0)} rb';
  }
  return '$sign${absolute.toStringAsFixed(0)}';
}

String formatDate(DateTime value) =>
    DateFormat('d MMM yyyy', 'id_ID').format(value);

String formatDayHeader(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  if (date == today) return 'Hari ini';
  if (date == today.subtract(const Duration(days: 1))) return 'Kemarin';
  return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(value);
}

String formatMonth(DateTime value) =>
    DateFormat('MMMM yyyy', 'id_ID').format(value);

String formatShortMonth(DateTime value) =>
    DateFormat('MMM', 'id_ID').format(value);

double parseMoney(String input) {
  final normalized = input.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(normalized) ?? 0;
}
