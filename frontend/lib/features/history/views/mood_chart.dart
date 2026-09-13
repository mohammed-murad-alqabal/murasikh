import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/history_service.dart';
import '../../../core/theme/app_colors.dart';

class MoodChart extends StatelessWidget {
  final List<HistoryItem> history;
  const MoodChart({super.key, required this.history});

  double _getEmotionScore(String emotion) {
    switch (emotion) {
      case 'فرح':
      case 'شكر':
        return 3;
      case 'طبيعي':
        return 2;
      case 'توتر':
      case 'قلق':
        return 1;
      case 'حزن':
      case 'حزن شديد':
      case 'غضب':
      case 'غضب شديد':
      case 'يأس':
      case 'إرهاق':
      case 'خوف':
      case 'ذنب':
      case 'مرض':
        return 0;
      default:
        return 2;
    }
  }

  String _getEmotionLabel(double score) {
    if (score >= 3) return 'إيجابي';
    if (score >= 2) return 'مستقر';
    if (score >= 1) return 'قلق';
    return 'منخفض';
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    // نأخذ آخر 10 سجلات للمخطط (أو كلها إذا كانت أقل) ونرتبها زمنياً (من الأقدم للأحدث)
    final recentHistory = history.take(10).toList().reversed.toList();
    
    final spots = recentHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _getEmotionScore(e.value.recommendation.emotion));
    }).toList();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مؤشر الحالة النفسية مؤخراً',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (value != 0 && value != 1 && value != 2 && value != 3) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              _getEmotionLabel(value),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              textAlign: TextAlign.left,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: -0.5,
                  maxY: 3.5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
