import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/database_helper.dart';

class CategoryPieChart extends StatelessWidget {
  final Map<String, int> counts;

  const CategoryPieChart({super.key, required this.counts});

  static const Map<String, Color> _colors = {
    'Computer Science & AI': Color(0xFF4A90E2),
    'Medicine & Biology': Color(0xFF50C878),
    'Physics & Mathematics': Color(0xFF9B59B6),
    'Psychology & Social Sciences': Color(0xFFE67E22),
    'Law & Political Science': Color(0xFFE74C3C),
    'Engineering & Other': Color(0xFF7F8C8D),
  };

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text('Add papers to see the category breakdown.'),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final legend = <Widget>[];

    for (final cat in DatabaseHelper.categories) {
      final count = counts[cat] ?? 0;
      if (count == 0) continue;

      final pct = count / total * 100;
      final color = _colors[cat] ?? Colors.grey;

      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          color: color,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      legend.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text('$cat ($count)',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          children: legend,
        ),
      ],
    );
  }
}