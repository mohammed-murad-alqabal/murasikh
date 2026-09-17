import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../services/ambient_listening_service.dart';
import '../../../../services/face_emotion_service.dart';
import '../../../../services/home_context_service.dart';
import '../../../../services/daily_verse_service.dart';
import '../../../../services/settings_service.dart';
import '../../../../features/home/models/verse_card.dart';
import '../../../face_emotion/face_emotion_screen.dart';
import '../../../../services/notification_service.dart';
import '../../../notifications/presentation/screens/notification_center_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AmbientListeningService _ambientService = AmbientListeningService();
  final FaceEmotionService _faceService = FaceEmotionService();
  final HomeContextService _contextService = HomeContextService();
  final DailyVerseService _verseService = DailyVerseService();
  final SettingsService _settingsService = SettingsService();

  bool _isCameraInitializing = false;
  String _userName = 'مُرَسِّخ';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _ambientService.addListener(_onAmbientError);
  }

  Future<void> _loadInitialData() async {
    final settings = _settingsService.getSettings();
    if (mounted) {
      setState(() => _userName = settings.name);
    }
    await _contextService.evaluateFromHistory();
    await _verseService.fetchVerseForCurrentContext();
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

  Future<void> _onRefresh() async {
    await _contextService.evaluateFromHistory();
    await _verseService.fetchVerseForCurrentContext();
  }

  Future<void> _toggleGuardian(bool value) async {
    if (value) {
      await _ambientService.startListening();
    } else {
      await _ambientService.stopListening();
    }
  }

  Future<void> _toggleFaceAnalysis(bool value) async {
    if (!_faceService.isCameraReady && value) {
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
      'سكينة': '🙂',
      'حزن': '😔',
      'قلق': '😟',
      'لم يتم اكتشاف وجه': '🔍',
      'طبيعي': '🌿',
    };
    return map[emotion] ?? '😐';
  }

  String _buildGreeting() {
    final time = HomeContextService.currentTimeOfDay();
    final name = _userName;

    switch (time) {
      case 'فجر':
        return 'طاب فجرك، $name 🌙';
      case 'صباح':
        return 'صباح النور، $name ☀️';
      case 'ظهر':
        return 'طاب نهارك، $name 🌤️';
      case 'عصر':
        return 'طاب عصرك، $name 🌅';
      case 'مساء':
        return 'مساء النور، $name 🌆';
      case 'ليل':
        return 'طاب ليلك، $name 🌃';
      default:
        return 'السلام عليكم، $name';
    }
  }

  String _formatArabicDate() {
    final now = DateTime.now();
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    const days = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
      'الجمعة', 'السبت', 'الأحد',
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
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIslamicHeader(context),
                const SizedBox(height: 16),
                _buildDailyInspirationCard(context),
                const SizedBox(height: 16),
                _buildAmbientGuardianCard(context),
                const SizedBox(height: 16),
                _buildFaceEmotionCard(context),
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

  Widget _buildIslamicHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
          const SizedBox(width: 16),
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
                Text(
                  _buildGreeting(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'رفيقك الروحي في كل حال',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: NotificationService(),
            builder: (context, _) {
              final unreadCount = NotificationService().unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationCenterScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 9 ? '+9' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildDailyInspirationCard(BuildContext context) {
    return StreamBuilder<VerseCard>(
      stream: _verseService.verseStream,
      initialData: _verseService.currentVerse,
      builder: (context, snapshot) {
        final card = snapshot.data;
        final isLoading = !snapshot.hasData && !snapshot.hasError;

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
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFFAF7EE)],
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
                    Row(
                      children: [
                        const Icon(
                          Icons.bookmark_outline,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (!isLoading && card != null && card.signalUsed != 'time') 
                             ? card.signalLabel 
                             : 'آية اليوم وسكينة القلب',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.secondary,
                        ),
                      )
                    else if (card != null)
                      _buildSourceBadge(card.source),
                  ],
                ),
                const SizedBox(height: 24),
                if (isLoading)
                  _buildVerseShimmer()
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    child: _buildVerseContent(card ?? VerseCard.fallback),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceBadge(String source) {
    if (source.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        source,
        style: const TextStyle(
          color: Color(0xFF8C731E),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildVerseContent(VerseCard card) {
    return Column(
      key: ValueKey('${card.verse}_${card.source}'),
      children: [
        Text(
          card.verse,
          style: AppTypography.quranText.copyWith(
            fontSize: 22,
            height: 1.8,
            color: const Color(0xFF0F3A3A),
          ),
          textAlign: TextAlign.center,
        ),
        if (card.tafsir != null && card.tafsir!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            card.tafsir!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildVerseShimmer() {
    return Column(
      children: [
        Container(
          height: 16,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        Container(
          height: 16,
          width: 220,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  Widget _buildAmbientGuardianCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _ambientService,
      builder: (context, _) {
        final isGuardianActive = _ambientService.isListening;
        final liveSpeech = _ambientService.liveSpeech;
        final latestAlert = _ambientService.latestRecommendation;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isGuardianActive
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : Colors.black12,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                value: isGuardianActive,
                onChanged: _toggleGuardian,
                activeThumbColor: AppColors.primary,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isGuardianActive
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isGuardianActive ? Icons.hearing : Icons.hearing_disabled,
                    color: isGuardianActive ? AppColors.primary : AppColors.textSecondary,
                    size: 26,
                  ),
                ),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'حارس السكينة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (isGuardianActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Text(
                          'مُفعّل 🌿',
                          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    isGuardianActive
                        ? 'يستمع بهدوء ويرسل تنبيهات قرآنية عند استشعار انفعال'
                        : 'متوقف حالياً، فعّله لمراقبة سكينتك',
                    style: TextStyle(
                      fontSize: 12,
                      color: isGuardianActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (isGuardianActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      const Divider(height: 20),
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              liveSpeech.isNotEmpty ? liveSpeech : 'النظام في وضع الاستماع المحيطي الهادئ...',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.notifications_active_outlined, size: 14, color: AppColors.secondary),
                            label: const Text('اختبار', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                            onPressed: () => _ambientService.testTriggerAlert(),
                          ),
                        ],
                      ),
                      if (latestAlert != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'تنبيه السكينة (${latestAlert.emotion}):',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                latestAlert.message,
                                style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

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
              color: isAnalyzing ? AppColors.primary.withValues(alpha: 0.5) : Colors.black12,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                value: isAnalyzing,
                onChanged: _toggleFaceAnalysis,
                activeThumbColor: AppColors.primary,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAnalyzing ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isCameraInitializing
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Icon(
                          Icons.face_retouching_natural,
                          color: isAnalyzing ? AppColors.primary : AppColors.textSecondary,
                          size: 26,
                        ),
                ),
                title: const Text(
                  'تحليل تعابير الوجه',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    isAnalyzing ? 'يحلل تعابيرك محلياً لتقديم مواساة فورية' : 'مستشعر الوجه مغلق لتوفير الطاقة',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAnalyzing ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
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
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_full, size: 18, color: AppColors.primary),
                            tooltip: 'الشاشة الكاملة',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FaceEmotionScreen()),
                            ),
                          ),
                        ],
                      ),
                      if (rec != null && emotion != 'طبيعي' && emotion != 'سكينة') ...[
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

  Widget _buildQuickMoodInsight(BuildContext context) {
    return AnimatedBuilder(
      animation: _contextService,
      builder: (context, _) {
        final currentEmotion = _contextService.current.dominantEmotion;
        final displayEmotion = (currentEmotion == 'طبيعي' || currentEmotion.isEmpty)
            ? 'في سكينة واطمئنان 🌿'
            : currentEmotion;
            
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
                    const SizedBox(height: 4),
                    Text(
                      'الحالة الحالية: $displayEmotion',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
            ],
          ),
        );
      },
    );
  }
}
