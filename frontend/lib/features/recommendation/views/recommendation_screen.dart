import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/recommendation_bloc.dart';
import '../models/recommendation_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'mic_button.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasFeedback = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    context.read<RecommendationBloc>().add(
      GetRecommendationEvent(_controller.text.trim()),
    );
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرفيق الروحي'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<RecommendationBloc, RecommendationState>(
                builder: (context, state) {
                  if (state is RecommendationLoading) {
                    return _buildLoadingView();
                  } else if (state is RecommendationError) {
                    return _buildErrorView(context, state.message);
                  } else if (state is RecommendationLoaded) {
                    return _buildResponseView(context, state.recommendation);
                  }
                  return _buildEmptyView(context);
                },
              ),
            ),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  // ── حالة الانتظار / Loading ─────────────────────────────────────
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'جارٍ البحث عن ما يواسيك...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── حالة خطأ ────────────────────────────────────────────────────
  Widget _buildErrorView(BuildContext context, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  // ── الشاشة الفارغة (الترحيب) ────────────────────────────────────
  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'الرفيق مستعد للاستماع إليك 🤍',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اكتب ما يجول في خاطرك، وسيجلب لك الله آيةً من القرآن الكريم تواسيك',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── بطاقة الرد الدافئ (القلب) ───────────────────────────────────
  Widget _buildResponseView(BuildContext context, RecommendationModel rec) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ── شريط الشعور المكتشف ─────────────────────────────
          _EmotionChip(emotion: rec.emotion),
          const SizedBox(height: 16),

          // ── البطاقة الرئيسية ─────────────────────────────────
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رسالة المواساة الدافئة (المصاغة من Gemini)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🤍', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.message,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(height: 1.7),
                        ),
                      ),
                    ],
                  ),

                  // المصدر (الآية)
                  if (rec.source != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rec.source!,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // التفسير إن وُجد
                  if (rec.tafsir != null &&
                      rec.tafsir!.isNotEmpty &&
                      rec.tafsir != 'التفسير متاح عند الطلب') ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'لمحة من التفسير',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rec.tafsir!,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(height: 1.5),
                    ),
                  ],

                  // أزرار التفاعل (نسخ + تقييم)
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: '${rec.message}\n${rec.source ?? ''}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ الرسالة 📋'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ الرسالة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),

                      // Feedback
                      if (!_hasFeedback)
                        Row(
                          children: [
                            Text(
                              'هل ساعدتك؟',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.thumb_up_alt_outlined,
                                size: 20,
                                color: Colors.green.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _hasFeedback = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'شكراً لتقييمك الإيجابي! سيتعلم النظام منه.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.thumb_down_alt_outlined,
                                size: 20,
                                color: Colors.red.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _hasFeedback = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'شكراً لملاحظتك. سنقوم بتحسين النتائج مستقبلاً.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        )
                      else
                        Text(
                          'شكراً لتقييمك!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── رسالة مؤجلة (للانفعالات الشديدة) ──────────────
          if (rec.delayedMessage != null) ...[
            const SizedBox(height: 16),
            _DelayedMessageCard(message: rec.delayedMessage!),
          ],
        ],
      ),
    );
  }

  // ── شريط الإدخال السفلي ─────────────────────────────────────────
  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'صِف مشاعرك أو موقفك...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(width: 8),
          BlocBuilder<RecommendationBloc, RecommendationState>(
            builder: (context, state) {
              final isLoading = state is RecommendationLoading;
              if (isLoading) {
                return const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              return Row(
                children: [
                  const MicButton(),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _submit,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── ويدجت شريط الشعور ──────────────────────────────────────────────
class _EmotionChip extends StatelessWidget {
  final String emotion;
  const _EmotionChip({required this.emotion});

  Color _emotionColor() {
    switch (emotion) {
      case 'غضب':
      case 'غضب شديد':
        return Colors.red.shade700;
      case 'حزن':
      case 'حزن شديد':
        return Colors.blue.shade700;
      case 'قلق':
      case 'توتر':
        return Colors.orange.shade700;
      case 'يأس':
        return Colors.purple.shade700;
      case 'فرح':
      case 'شكر':
        return Colors.green.shade700;
      default:
        return AppColors.primary;
    }
  }

  String _emotionEmoji() {
    switch (emotion) {
      case 'غضب':
      case 'غضب شديد':
        return '😤';
      case 'حزن':
      case 'حزن شديد':
        return '😢';
      case 'قلق':
        return '😟';
      case 'توتر':
      case 'إرهاق':
        return '😰';
      case 'يأس':
        return '😞';
      case 'فرح':
        return '😊';
      case 'شكر':
        return '🙏';
      case 'خوف':
        return '😨';
      case 'ذنب':
        return '😔';
      default:
        return '🙂';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _emotionColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _emotionColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emotionEmoji(), style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            'الشعور المكتشف: $emotion',
            style: TextStyle(
              color: _emotionColor(),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── بطاقة الرسالة المؤجلة ──────────────────────────────────────────
class _DelayedMessageCard extends StatelessWidget {
  final String message;
  const _DelayedMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.nightlight_round,
                  color: Colors.purple,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'رسالة التأمل (بعد الهدوء)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
