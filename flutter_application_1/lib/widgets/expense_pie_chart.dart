import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ExpensePieChart extends StatelessWidget {
  final List categories;

  const ExpensePieChart({
    super.key,
    required this.categories,
  });

  Color _getCategoryColor(String category) {
    final colors = {
      "Market": const Color(0xFF1E6B52),
      "Yeme İçme": const Color(0xFFC96B3B),
      "Ulaşım": const Color(0xFF3C6E71),
      "Eğlence": const Color(0xFF9C6ADE),
      "Alışveriş": const Color(0xFFD96C8A),
      "Diger": const Color(0xFF7B887F),
      "Diğer": const Color(0xFF7B887F),
    };
    return colors[category] ?? const Color(0xFF5C7C6D);
  }

  @override
  Widget build(BuildContext context) {
    final safeCategories = categories.cast<Map<String, dynamic>>();
    final total = safeCategories.fold<double>(
      0,
      (sum, item) => sum + ((item["amount"] as num?)?.toDouble() ?? 0),
    );

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 58,
              startDegreeOffset: -90,
              sections: safeCategories.map((item) {
                final amount = (item["amount"] as num?)?.toDouble() ?? 0;
                final name = item["name"]?.toString() ?? "-";
                final ratio = total > 0 ? (amount / total) * 100 : 0.0;

                return PieChartSectionData(
                  value: amount,
                  color: _getCategoryColor(name),
                  title: ratio < 8 ? "" : "%${ratio.toStringAsFixed(0)}",
                  radius: 86,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: safeCategories.map((item) {
            final name = item["name"]?.toString() ?? "-";
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F1E8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(name),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF33413A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}