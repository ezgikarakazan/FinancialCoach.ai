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
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: List.generate(
                monthlyExpenses.length,
                (index) => FlSpot(
                  index.toDouble(),
                  monthlyExpenses[index]["amount"]
                      .toDouble(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}