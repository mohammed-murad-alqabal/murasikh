import 'package:flutter/material.dart';

import '../../services/history_service.dart';
import '../../services/api_service.dart';
import '../../core/theme/app_colors.dart';
import 'views/mood_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory();
    if (mounted) {
      setState(() {
        _history = history.reversed.toList();
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح السجل'),
        content: const Text('هل أنت متأكد من مسح جميع سجلات التوجيه؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyService.clearHistory();
      _loadHistory();
    }
  }

  Future<void> _updateFeedback(String id, int feedback) async {
    // ApiService يتعامل تلقائياً مع الإرسال المباشر أو التأجيل عند انقطاع الإنترنت
    await ApiService().submitFeedback(id, feedback);
    _loadHistory();
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السجل'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _history.isEmpty
          ? Center(
              child: Text(
                'لا يوجد سجل حتى الآن.\nتحدث أو استخدم الكاميرا لتبدأ التسجيل.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _history.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: MoodChart(history: _history),
                  );
                }

                final item = _history[index - 1];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'الشعور: ${item.recommendation.emotion}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Text(
                              _formatTime(item.timestamp),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'النص/الموقف:',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        Text(
                          item.inputText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Divider(height: 24),
                        Text(
                          'توجيه مُرَسِّخ:',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.recommendation.message,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                height: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (item.recommendation.source != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.recommendation.source!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.primaryLight),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'هل كان التوجيه مناسباً؟',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    item.feedback == 1
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_alt_outlined,
                                    color: item.feedback == 1
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                  onPressed: () => _updateFeedback(
                                    item.id,
                                    item.feedback == 1 ? 0 : 1,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    item.feedback == -1
                                        ? Icons.thumb_down
                                        : Icons.thumb_down_alt_outlined,
                                    color: item.feedback == -1
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                  ),
                                  onPressed: () => _updateFeedback(
                                    item.id,
                                    item.feedback == -1 ? 0 : -1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
