import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../services/ambient_listening_service.dart';
import '../../../../services/face_emotion_service.dart';
import '../../../../services/history_service.dart';
import '../../../face_emotion/face_emotion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AmbientListeningService _ambientService = AmbientListeningService();
  final FaceEmotionService _faceService = FaceEmotionService();
  final HistoryService _historyService = HistoryService();

  bool _isCameraInitializing = false;
  String _latestEmotionSummary = 'في سكينة واطمئنان 🌿';

  @override
  void initState() {
    super.initState();
    _loadRecentMoodSummary();

    // Listen to errors from ambient service globally via a listener
    _ambientService.addListener(_onAmbientError);
  }

  void _onAmbientError() {
    if (_ambientService.errorMessage.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ambientService.errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ambientService.removeListener(_onAmbientError);
    super.dispose();
  }

  Future<void> _loadRecentMoodSummary() async {
    try {
      final history = await _historyService.getHistory();
      if (history.isNotEmpty && mounted) {
        final last = history.first;
        setState(() {
          _latestEmotionSummary =
              'آخر حالة مسجلة: ${last.recommendation.emotion}';
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleGuardian(bool value) async {
    if (value) {
      await _ambientService.startListening();
    } else {
      await _ambientService.stopListening();
    }
  }

  Future<void> _toggleFaceAnalysis() async {
    if (!_faceService.isCameraReady) {
      setState(() => _isCameraInitializing = true);
      await _faceService.initialize();
      if (mounted) {
        setState(() => _isCameraInitializing = false);
      }
    }
    _faceService.toggleAnalysis();
  }

  String _emotionToEmoji(String emotion) {
    const map = {
      'فرح': '😊',
      'بشاشة': '🙂',
      'إجهاد أو حزن': '😔',
      'قلق أو توتر': '😟',
      'لم يتم اكتشاف وجه': '🔍',
      'طبيعي': '🌿',
    };
    return map[emotion] ?? '😐';
  }

  String _formatArabicDate() {
    final now = DateTime.now();
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName، ${now.day} $monthName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadRecentMoodSummary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIslamicHeader(context),
                const SizedBox(height: 16),
                _buildAmbientGuardianCard(context),
                const SizedBox(height: 16),
                _buildFaceEmotionCard(context),
                const SizedBox(height: 16),
                _buildDailyInspirationCard(context),
                const SizedBox(height: 16),
                _buildQuickMoodInsight(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ترويسة إسلامية أنيقة مع التاريخ وعبارة ترحيبية
  Widget _buildIslamicHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3A3A), Color(0xFF115E59)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatArabicDate(),
                      style: const TextStyle(
                        color: AppColors.secondaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'السلام عليكم ورحمة الله',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'أهلاً بك في رفيقك الروحي مُرَسِّخ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary, width: 2),
            ),
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white12,
              child: Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة حارس السكينة المطورة
  Widget _buildAmbientGuardianCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _ambientService,
      builder: (context, _) {
        final activeColor = AppColors.primary;
        final inactiveColor = AppColors.textSecondary;
        final isGuardianActive = _ambientService.isListening;
        final liveSpeech = _ambientService.liveSpeech;
        final latestAlert = _ambientService.latestRecommendation;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isGuardianActive
                  ? activeColor.withValues(alpha: 0.6)
                  : Colors.black12,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isGuardianActive
                            ? activeColor.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isGuardianActive
                            ? Icons.hearing
                            : Icons.hearing_disabled,
                        color: isGuardianActive ? activeColor : inactiveColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'حارس السكينة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (isGuardianActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: const Text(
                                    'مُفعّل 🌿',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isGuardianActive
                                ? 'يستمع بهدوء ويرسل تنبيهات قرآنية عند استشعار انفعال'
                                : 'متوقف حالياً، فعّله لمراقبة سكينتك',
                            style: TextStyle(
                              fontSize: 12,
                              color: isGuardianActive
                                  ? activeColor
                                  : inactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isGuardianActive,
                      activeThumbColor: AppColors.primary,
                      onChanged: _toggleGuardian,
                    ),
                  ],
                ),
                if (isGuardianActive) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          liveSpeech.isNotEmpty
                              ? liveSpeech
                              : 'النظام في وضع الاستماع المحيطي الهادئ...',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // زر تجربة الإشعار للتأكد من فاعلية التنبيه
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        label: const Text(
                          'اختبار',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        ),
                        onPressed: () => _ambientService.testTriggerAlert(),
                      ),
                    ],
                  ),
                ],
                if (latestAlert != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'تنبيه السكينة (${latestAlert.emotion}):',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestAlert.message,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// بطاقة مستشعر الوجه والتعابير مع تهيئة كسولة وعرض قابل للطي
  Widget _buildFaceEmotionCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _faceService,
      builder: (context, _) {
        final isReady = _faceService.isCameraReady;
        final isAnalyzing = _faceService.isAnalyzing;
        final emotion = _faceService.detectedEmotion;
        final emoji = emotion.isNotEmpty ? _emotionToEmoji(emotion) : '📷';
        final rec = _faceService.recommendation;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isAnalyzing
                  ? Colors.teal.withValues(alpha: 0.5)
                  : Colors.black12,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAnalyzing
                            ? Colors.teal.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.face_retouching_natural,
                        color: isAnalyzing
                            ? Colors.teal.shade700
                            : AppColors.textSecondary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تحليل تعابير الوجه',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAnalyzing
                                ? 'يحلل تعابيرك محلياً لتقديم مواساة فورية'
                                : 'مستشعر الوجه مغلق لتوفير الطاقة',
                            style: TextStyle(
                              fontSize: 12,
                              color: isAnalyzing
                                  ? Colors.teal.shade700
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isCameraInitializing)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: isAnalyzing,
                        activeThumbColor: Colors.teal,
                        onChanged: (_) => _toggleFaceAnalysis(),
                      ),
                  ],
                ),
              ),
              // المعاينة الحية تظهر فقط عندما يكون التحليل مفعلاً
              if (isAnalyzing) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isReady && _faceService.cameraController != null
                        ? CameraPreview(_faceService.cameraController!)
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'الشعور المكتشف: $emotion',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.open_in_full,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            tooltip: 'الشاشة الكاملة',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FaceEmotionScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rec != null &&
                          emotion != 'طبيعي' &&
                          emotion != 'بشاشة') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rec.message,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// آية اليوم وسكينة القلب
  Widget _buildDailyInspirationCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFFFAF7EE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bookmark_outline,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'آية اليوم وسكينة القلب',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'سورة البقرة: ١٥٢',
                    style: TextStyle(
                      color: Color(0xFF8C731E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'فَاذۡكُرُونِيٓ أَذۡكُرۡكُمۡ وَٱشۡكُرُواْ لِي وَلَا تَكۡفُرُونِ',
              style: AppTypography.quranText.copyWith(
                fontSize: 18,
                height: 1.8,
                color: const Color(0xFF0F3A3A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'من ذكر الله في نفسه ذكره الله في ملأ خير منهم، وبذكره تطيب الحياة وتنجلي الكروب.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة نبض اليوم وملخص الاستقرار
  Widget _buildQuickMoodInsight(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مؤشر السكينة اليومي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  _latestEmotionSummary,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
