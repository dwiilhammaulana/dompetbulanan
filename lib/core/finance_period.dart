class FinancePeriod {
  const FinancePeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _monthWithOffset(DateTime date, int offset) =>
      DateTime(date.year, date.month + offset);

  static DateTime _clampedDay(int year, int month, int preferredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, preferredDay.clamp(1, lastDay));
  }

  /// Membentuk siklus berulang. Jika tanggal awal adalah 25, rentang akan
  /// otomatis menjadi 25 bulan ini sampai 24 bulan berikutnya.
  factory FinancePeriod.cycleContaining(DateTime anchor, int startDay) {
    final day = dateOnly(anchor);
    var start = _clampedDay(day.year, day.month, startDay);
    if (day.isBefore(start)) {
      final previousMonth = _monthWithOffset(day, -1);
      start = _clampedDay(previousMonth.year, previousMonth.month, startDay);
    }
    final nextMonth = _monthWithOffset(start, 1);
    final nextStart = _clampedDay(nextMonth.year, nextMonth.month, startDay);
    return FinancePeriod(
      start: start,
      end: nextStart.subtract(const Duration(days: 1)),
    );
  }

  factory FinancePeriod.calendarMonth(DateTime month) => FinancePeriod(
    start: DateTime(month.year, month.month),
    end: DateTime(month.year, month.month + 1, 0),
  );

  factory FinancePeriod.calendarYear(int year) =>
      FinancePeriod(start: DateTime(year), end: DateTime(year, 12, 31));

  FinancePeriod previousCycle(int startDay) => FinancePeriod.cycleContaining(
    start.subtract(const Duration(days: 1)),
    startDay,
  );

  bool contains(DateTime value) {
    final day = dateOnly(value);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  int get dayCount => end.difference(start).inDays + 1;
}
