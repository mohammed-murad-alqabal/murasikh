import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../services/face_emotion_service.dart';
import '../../../../services/ambient_listening_service.dart';
import '../../../../services/home_context_service.dart';
import '../../../../services/daily_verse_service.dart';
import '../../../../services/settings_service.dart';
import '../../../../services/notification_service.dart';

import '../../../face_emotion/face_emotion_screen.dart';
import '../../../notifications/presentation/screens/notification_center_screen.dart';
import '../../models/verse_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FaceEmotionService _faceService = FaceEmotionService();
  final AmbientListeningService _ambientService = AmbientListeningService();
  final HomeContextService _contextService = HomeContextService();
  final DailyVerseService _verseService = DailyVerseService();
  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();

  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _ambientService.addListener(_onAmbientError);
    _notificationService.addListener(_onNotificationsChanged);
    _contextService.addListener(_onContextChanged);
    _verseService.verseStream.listen((_) {
      if (mounted) setState(() {});
    });

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _contextService.evaluateFromHistory();
      await _verseService.fetchVerseForCurrentContext();
    });
  }

  @override
  void dispose() {
    _ambientService.removeListener(_onAmbientError);
    _notificationService.removeListener(_onNotificationsChanged);
    _contextService.removeListener(_onContextChanged);
    _breathingController.dispose();
    super.dispose();
  }

  void _onAmbientError() {
    if (_ambientService.errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ambientService.errorMessage),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _onContextChanged() {
    if (mounted) setState(() {});
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

  String _buildGreeting() {
    final time = HomeContextService.currentTimeOfDay();
    final name = _settingsService.getSettings().name;

    switch (time) {
      case 'فجر': return 'طاب فجرك، $name 🌙';
      case 'صباح': return 'صباح النور، $name ☀️';
      case 'ظهر': return 'طاب نهارك، $name 🌤️';
      case 'عصر': return 'طاب عصرك، $name 🌅';
      case 'مساء': return 'مساء النور، $name 🌆';
      case 'ليل': return 'طاب ليلك، $name 🌃';
      default: return 'السلام عليكم، $name';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _contextService.evaluateFromHistory(forceRefresh: true);
            await _verseService.fetchVerseForCurrentContext();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: _buildIslamicHeader(context),
                )
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      _buildHeroVerseHub(context),
                      const SizedBox(height: 16),
                      _buildMiniSensorsBar(context),
                      const SizedBox(height: 16),
                      _buildContextualActionCard(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
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
            animation: _notificationService,
            builder: (context, _) {
              final unreadCount = _notificationService.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationCenterScreen(),
                        ),
                      ).then((_) => setState((){}));
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

  Color _getGradientStart(String emotion) {
    switch (emotion) {
      case 'حزن':
      case 'اكتئاب':
        return const Color(0xFF2C3E50);
      case 'قلق':
      case 'توتر':
        return const Color(0xFF4A148C);
      case 'غضب':
        return const Color(0xFFC62828);
      case 'سكينة':
      case 'طبيعي':
      default:
        return const Color(0xFF0F3A3A);
    }
  }

  Color _getGradientEnd(String emotion) {
    switch (emotion) {
      case 'حزن':
      case 'اكتئاب':
        return const Color(0xFF3498DB);
      case 'قلق':
      case 'توتر':
        return const Color(0xFF8E24AA);
      case 'غضب':
        return const Color(0xFFEF5350);
      case 'سكينة':
      case 'طبيعي':
      default:
        return const Color(0xFF115E59);
    }
  }

  Widget _buildHeroVerseHub(BuildContext context) {
    final currentEmotion = _contextService.current.dominantEmotion;
    final colorStart = _getGradientStart(currentEmotion);
    final colorEnd = _getGradientEnd(currentEmotion);

    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        final double pulse = 1.0 + (_breathingController.value * 0.02);

        return Transform.scale(
          scale: pulse,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorStart, colorEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colorStart.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: StreamBuilder<VerseCard>(
              stream: _verseService.verseStream,
              initialData: _verseService.currentVerse,
              builder: (context, snapshot) {
                final card = snapshot.data;
                if (card == null) return _buildVerseShimmer();

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: _buildVerseContent(card),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseContent(VerseCard card) {
    String contextLabel = 'آية اليوم وسكينة القلب';
    if (card.signalUsed == 'face' || card.signalUsed == 'audio') {
      contextLabel = 'بناءً على ما تشعر به الآن...';
    } else if (card.signalUsed == 'history') {
      contextLabel = 'رفيقك الروحي يواسيك...';
    }

    return Column(
      key: ValueKey('${card.verse}_${card.source}'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              contextLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          card.verse,
          style: AppTypography.quranText.copyWith(
            color: Colors.white,
            fontSize: 24,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            card.source,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (card.tafsir != null && card.tafsir!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Text(
            card.tafsir!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildVerseShimmer() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(height: 16, width: 100, color: Colors.white24),
        const SizedBox(height: 30),
        Container(height: 24, width: double.infinity, color: Colors.white24),
        const SizedBox(height: 10),
        Container(height: 24, width: 200, color: Colors.white24),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildMiniSensorsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSensorStatus(
            title: 'حارس السكينة',
            isActive: _ambientService.isListening,
            icon: Icons.mic_rounded,
            onTap: () {
              if (_ambientService.isListening) {
                _ambientService.stopListening();
                setState(() {});
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('حارس السكينة (صلاحية الميكروفون)'),
                    content: const Text('لتفعيل "حارس السكينة"، يحتاج التطبيق إلى صلاحية تسجيل الصوت لفترات قصيرة لتحليل التوتر.\nنؤكد لك أنه لا يتم حفظ أو مشاركة أي مقاطع صوتية؛ تُحذف فور التحليل.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _ambientService.startListening().then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                        child: const Text('موافق'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildSensorStatus(
            title: 'تحليل الوجه',
            isActive: _faceService.isAnalyzing,
            icon: Icons.face_retouching_natural,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaceEmotionScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSensorStatus({
    required String title,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.primary : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.textPrimary : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextualActionCard(BuildContext context) {
    final currentEmotion = _contextService.current.dominantEmotion;
    if (currentEmotion == 'طبيعي' || currentEmotion.isEmpty || currentEmotion == 'سكينة') {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'هل ترغب بالفضفضة؟',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'لاحظت أنك تشعر بـ $currentEmotion. أنا هنا للاستماع إليك.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
