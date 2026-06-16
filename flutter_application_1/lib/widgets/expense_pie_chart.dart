import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ExpensePieChart extends StatelessWidget {
  final List categories;

  const ExpensePieChart({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: categories.map((item) {
            return PieChartSectionData(
              value: item["amount"].toDouble(),
              title: item["name"],
              radius: 80,
            );
          }).toList(),
        ),
      ),
    );
  }
}