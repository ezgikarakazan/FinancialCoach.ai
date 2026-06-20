import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrendLineChart extends StatelessWidget {
  final List monthlyExpenses;

  const TrendLineChart({
    super.key,
    required this.monthlyExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final safeMonthly = monthlyExpenses.cast<Map<String, dynamic>>();
    final spots = List.generate(
      safeMonthly.length,
      (index) => FlSpot(
        index.toDouble(),
        ((safeMonthly[index]["amount"] as num?)?.toDouble() ?? 0),
      ),
    );

    double maxY = 0;
    for (final item in safeMonthly) {
      final amount = (item["amount"] as num?)?.toDouble() ?? 0;
      if (amount > maxY) {
        maxY = amount;
      }
    }

    if (maxY == 0) {
      maxY = 100;
    }

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.25,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) {
              return const FlLine(
                color: Color(0xFFE8E1D7),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: false,
          ),
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
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7B887F),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= safeMonthly.length) {
                    return const SizedBox.shrink();
                  }

                  final label = safeMonthly[index]["month"]?.toString() ?? "";
                  final shortLabel = label.length > 3 ? label.substring(0, 3) : label;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      shortLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7B887F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E2722),
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final amount = spot.y.toStringAsFixed(2);
                  return LineTooltipItem(
                    "₺$amount",
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF9A5A36),
              barWidth: 4,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) {
                  return FlDotCirclePainter(
                    radius: 4.5,
                    color: const Color(0xFFFFFCF6),
                    strokeWidth: 3,
                    strokeColor: const Color(0xFF9A5A36),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9A5A36).withOpacity(0.25),
                    const Color(0xFF9A5A36).withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}