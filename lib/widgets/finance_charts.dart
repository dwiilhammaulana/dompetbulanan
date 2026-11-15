import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/finance_period.dart';
import '../core/formatters.dart';
import '../models/finance_models.dart';
import '../state/finance_controller.dart';

class SpendingComparisonChart extends StatelessWidget {
  const SpendingComparisonChart({
    super.key,
    required this.current,
    required this.previous,
    required this.currentPeriod,
    required this.previousPeriod,
  });

  final FinanceSummary current;
  final FinanceSummary previous;
  final FinancePeriod currentPeriod;
  final FinancePeriod previousPeriod;

  List<FlSpot> _cumulative(
    FinanceSummary summary,
    FinancePeriod period, {
    int? limit,
  }) {
    final spots = <FlSpot>[];
    var total = 0.0;
    final count = math.min(limit ?? period.dayCount, period.dayCount);
    for (var index = 0; index < count; index++) {
      final day = period.start.add(Duration(days: index));
      total += summary.dailyExpense[FinancePeriod.dateOnly(day)] ?? 0;
      spots.add(FlSpot((index + 1).toDouble(), total));
    }
    return spots.isEmpty ? const [FlSpot(1, 0)] : spots;
  }

  @override
  Widget build(BuildContext context) {
    final now = FinancePeriod.dateOnly(DateTime.now());
    final elapsed = currentPeriod.contains(now)
        ? now.difference(currentPeriod.start).inDays + 1
        : currentPeriod.dayCount;
    final currentSpots = _cumulative(current, currentPeriod, limit: elapsed);
    final previousSpots = _cumulative(previous, previousPeriod);
    final maxValue = math.max(
      currentSpots.map((spot) => spot.y).reduce(math.max),
      previousSpots.map((spot) => spot.y).reduce(math.max),
    );
    final maxY = maxValue <= 0 ? 100000.0 : maxValue * 1.18;
    final maxX = math
        .max(currentPeriod.dayCount, previousPeriod.dayCount)
        .toDouble();
    final interval = math.max(1, (maxX / 4).floor()).toDouble();

    return Column(
      children: [
        Row(
          children: [
            _Legend(color: AppColors.primary, label: 'Siklus ini'),
            const SizedBox(width: 16),
            const _Legend(color: Color(0xFFB9C4BF), label: 'Siklus lalu'),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 210,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: maxY / 4,
                    getTitlesWidget: (value, _) => Text(
                      formatCompactRupiah(value),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: interval,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        'H${value.round()}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceAlt,
                  fitInsideHorizontally: true,
                  getTooltipItems: (spots) => spots
                      .map(
                        (spot) => LineTooltipItem(
                          '${spot.barIndex == 0 ? 'Siklus ini' : 'Siklus lalu'}\n${formatRupiah(spot.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: currentSpots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: previousSpots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: const Color(0xFFB9C4BF),
                  barWidth: 2,
                  dashArray: [7, 5],
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 240),
          ),
        ),
      ],
    );
  }
}

class MonthlyCashFlowChart extends StatelessWidget {
  const MonthlyCashFlowChart({super.key, required this.data});

  final List<MonthlyCashFlow> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<double>(
      0,
      (result, item) => math.max(result, math.max(item.income, item.expense)),
    );
    final maxY = maxValue <= 0 ? 100000.0 : maxValue * 1.2;
    return Column(
      children: [
        const Row(
          children: [
            _Legend(color: AppColors.income, label: 'Pemasukan'),
            SizedBox(width: 16),
            _Legend(color: AppColors.expense, label: 'Pengeluaran'),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceAlt,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${rodIndex == 0 ? 'Masuk' : 'Keluar'}\n${formatRupiah(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: maxY / 4,
                    getTitlesWidget: (value, _) => Text(
                      formatCompactRupiah(value),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          formatShortMonth(data[index].month),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(data.length, (index) {
                final item = data[index];
                return BarChartGroupData(
                  x: index,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: item.income,
                      color: AppColors.income,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: item.expense,
                      color: AppColors.expense,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
            duration: const Duration(milliseconds: 240),
          ),
        ),
      ],
    );
  }
}

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({
    super.key,
    required this.summary,
    required this.categories,
  });

  final FinanceSummary summary;
  final List<FinanceCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (summary.expense <= 0) {
      return const SizedBox(
        height: 190,
        child: Center(
          child: Text(
            'Belum ada pengeluaran pada periode ini.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    final categoryMap = {
      for (final category in categories) category.id: category,
    };
    final entries = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 61,
              sectionsSpace: 3,
              startDegreeOffset: -90,
              sections: entries.map((entry) {
                final category = categoryMap[entry.key];
                return PieChartSectionData(
                  value: entry.value,
                  color: category?.color ?? AppColors.muted,
                  radius: 34,
                  showTitle: false,
                  borderSide: const BorderSide(
                    color: AppColors.surface,
                    width: 1,
                  ),
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 240),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total keluar',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                formatCompactRupiah(summary.expense),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
    ],
  );
}
