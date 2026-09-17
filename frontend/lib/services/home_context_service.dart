import 'package:flutter/foundation.dart';

import 'ambient_listening_service.dart';
import 'face_emotion_service.dart';
import 'history_service.dart';

/// لقطة سياق محسوبة في لحظة زمنية معينة
class ContextSnapshot {
  final String dominantEmotion;
  final double confidence;

  /// مصدر الإشارة: «face» | «audio» | «history» | «time»
  final String signalSource;

  final DateTime timestamp;

  const ContextSnapshot({
    required this.dominantEmotion,
    required this.confidence,
    required this.signalSource,
    required this.timestamp,
  });

  bool get isNeutral => dominantEmotion == 'طبيعي' || dominantEmotion.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextSnapshot &&
          other.dominantEmotion == dominantEmotion &&
          (other.confidence - confidence).abs() < 0.1 &&
          other.signalSource == signalSource);

  @override
  int get hashCode =>
      Object.hash(dominantEmotion, confidence.round(), signalSource);
}

/// سياسة القرار الخاصة بتحديث سياق الصفحة الرئيسية.
///
/// الدوال نقية ولا تعتمد على المستشعرات، مما يجعلها مناسبة لاختبارات الوحدة.
class HomeContextPolicy {
  static const double faceConfidenceThreshold = 0.65;
  static const double audioConfidenceThreshold = 0.60;
  static const double historyConfidence = 0.55;
  static const Duration forceRefreshInterval = Duration(minutes: 60);
  static const Duration minUpdateInterval = Duration(minutes: 3);

  static bool isSignificantChange(
    ContextSnapshot old,
    ContextSnapshot candidate, {
    DateTime? now,
  }) {
    if (old.dominantEmotion != candidate.dominantEmotion) return true;
    if (candidate.confidence - old.confidence > 0.25) return true;
    return (now ?? DateTime.now()).difference(old.timestamp) >
        forceRefreshInterval;
  }

  static double thresholdForSource(String source) {
    switch (source) {
      case 'face':
        return faceConfidenceThreshold;
      case 'audio':
        return audioConfidenceThreshold;
      case 'history':
        return historyConfidence;
      default:
        return 0.0;
    }
  }

  static bool shouldNotify({
    required ContextSnapshot old,
    required ContextSnapshot candidate,
    required DateTime lastNotifyTime,
    required DateTime now,
  }) {
    if (now.difference(lastNotifyTime) < minUpdateInterval) return false;
    if (!isSignificantChange(old, candidate, now: now)) return false;
    return candidate.confidence >= thresholdForSource(candidate.signalSource);
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// HomeContextService — مُحكّم السياق الموحَّد
///
/// يستمع لثلاثة مصادر متوازية:
///   1. FaceEmotionService  — مستشعر الوجه
///   2. AmbientListeningService — مستشعر الصوت
///   3. HistoryService — سجل التفاعلات الأخيرة
///
/// يُنتج ContextSnapshot واحداً موزوناً فقط عند تغيّر **ذي دلالة حقيقية**،
/// مُتجنِّباً التحديثات المتكررة والمزعجة.
/// ─────────────────────────────────────────────────────────────────────────
class HomeContextService extends ChangeNotifier {
  static final HomeContextService _instance = HomeContextService._internal();
  factory HomeContextService() => _instance;

  HomeContextService._internal() {
    _faceService.addListener(_onFaceChanged);
    _ambientService.addListener(_onAmbientChanged);
  }

  final FaceEmotionService _faceService = FaceEmotionService();
  final AmbientListeningService _ambientService = AmbientListeningService();
  final HistoryService _historyService = HistoryService();

  ContextSnapshot _current = ContextSnapshot(
    dominantEmotion: 'طبيعي',
    confidence: 0.0,
    signalSource: 'time',
    timestamp: DateTime(2000), // قيمة قديمة تضمن التحديث عند أول استدعاء
  );

  ContextSnapshot get current => _current;

  // ── عتبات التغيير ───────────────────────────────────────────────────────

  DateTime _lastNotifyTime = DateTime(2000);

  // ── مستمعو الأحداث ───────────────────────────────────────────────────────

  void _onFaceChanged() {
    final emotion = _faceService.detectedEmotion;
    if (emotion.isEmpty || emotion == 'لم يتم اكتشاف وجه') return;

    if (emotion == 'طبيعي') {
      // الانحدار التدريجي (Decay) للوضع الطبيعي (سياق الوقت)
      _evaluateAndMaybeNotify(ContextSnapshot(
        dominantEmotion: 'طبيعي',
        confidence: 1.0, // ثقة عالية بأن الحالة هادئة لكي تتجاوز العتبة
        signalSource: 'time',
        timestamp: DateTime.now(),
      ));
      return;
    }

    // الوجه يُعطى أعلى وزن للحالات الصريحة
    final confidence = emotion == 'سكينة'
        ? HomeContextPolicy.faceConfidenceThreshold
        : 0.80;

    _evaluateAndMaybeNotify(ContextSnapshot(
      dominantEmotion: emotion,
      confidence: confidence,
      signalSource: 'face',
      timestamp: DateTime.now(),
    ));
  }

  void _onAmbientChanged() {
    final rec = _ambientService.latestRecommendation;
    if (rec == null) return;

    final emotion = rec.emotion;
    if (emotion.isEmpty || emotion == 'طبيعي') return;

    _evaluateAndMaybeNotify(ContextSnapshot(
      dominantEmotion: emotion,
      confidence: HomeContextPolicy.audioConfidenceThreshold,
      signalSource: 'audio',
      timestamp: DateTime.now(),
    ));
  }

  /// يُستدعى يدوياً من الشاشة الرئيسية عند بدء التشغيل
  Future<void> evaluateFromHistory() async {
    try {
      final history = await _historyService.getHistory();
      if (history.isEmpty) return;

      // آخر 3 تفاعلات — نأخذ الحالة الأكثر تكراراً
      final recentEmotions = history
          .take(3)
          .map((h) => h.recommendation.emotion)
          .where((e) => e != 'طبيعي' && e.isNotEmpty)
          .toList();

      if (recentEmotions.isEmpty) return;

      // الحالة الأكثر تكراراً
      final emotionCounts = <String, int>{};
      for (final e in recentEmotions) {
        emotionCounts[e] = (emotionCounts[e] ?? 0) + 1;
      }
      final dominant =
          emotionCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      _evaluateAndMaybeNotify(ContextSnapshot(
        dominantEmotion: dominant,
        confidence: HomeContextPolicy.historyConfidence,
        signalSource: 'history',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('HomeContextService.evaluateFromHistory error: $e');
    }
  }

  // ── منطق القرار المركزي ──────────────────────────────────────────────────

  void _evaluateAndMaybeNotify(ContextSnapshot candidate) {
    final now = DateTime.now();
    if (!HomeContextPolicy.shouldNotify(
      old: _current,
      candidate: candidate,
      lastNotifyTime: _lastNotifyTime,
      now: now,
    )) return;

    _current = candidate;
    _lastNotifyTime = now;
    notifyListeners();
  }

  /// وقت اليوم الحالي بالعربية
  static String currentTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 6) return 'فجر';
    if (hour >= 6 && hour < 11) return 'صباح';
    if (hour >= 11 && hour < 14) return 'ظهر';
    if (hour >= 14 && hour < 17) return 'عصر';
    if (hour >= 17 && hour < 21) return 'مساء';
    return 'ليل';
  }

  @override
  void dispose() {
    _faceService.removeListener(_onFaceChanged);
    _ambientService.removeListener(_onAmbientChanged);
    super.dispose();
  }
}
