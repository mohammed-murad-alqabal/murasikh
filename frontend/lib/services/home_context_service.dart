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

  /// الحد الأدنى لثقة الوجه لاعتبار الحالة ذات دلالة
  static const double _faceConfidenceThreshold = 0.65;

  /// الحد الأدنى لثقة الصوت
  static const double _audioConfidenceThreshold = 0.60;

  /// حد الثقة من السجل (تقدير لأن HistoryService لا يوفر confidence مباشرة)
  static const double _historyConfidence = 0.55;

  /// الحد الأدنى للفارق الزمني بين تحديثين متتاليين (تجنب spam)
  static const Duration _minUpdateInterval = Duration(minutes: 3);

  /// إعادة التحديث القسري كل 60 دقيقة حتى لو لم تتغير الحالة
  static const Duration _forceRefreshInterval = Duration(minutes: 60);

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
    final confidence = emotion == 'سكينة' ? 0.65 : 0.80;

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
      confidence: _audioConfidenceThreshold,
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
        confidence: _historyConfidence,
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

    // 1. هل انقضى الحد الأدنى للفارق الزمني بين التحديثات؟
    if (now.difference(_lastNotifyTime) < _minUpdateInterval) return;

    // 2. هل هذا تغيّر ذو دلالة حقيقية؟
    if (!_isSignificantChange(_current, candidate)) return;

    // 3. هل الثقة كافية بناءً على المصدر؟
    final threshold = _thresholdForSource(candidate.signalSource);
    if (candidate.confidence < threshold) return;

    _current = candidate;
    _lastNotifyTime = now;
    notifyListeners();
  }

  bool _isSignificantChange(ContextSnapshot old, ContextSnapshot candidate) {
    // تغيّر نوع الحالة العاطفية
    if (old.dominantEmotion != candidate.dominantEmotion) return true;

    // زيادة ملحوظة في الثقة (أكثر من 25 نقطة)
    if (candidate.confidence - old.confidence > 0.25) return true;

    // إعادة التحديث القسري بعد مرور ساعة
    if (DateTime.now().difference(old.timestamp) > _forceRefreshInterval) {
      return true;
    }

    return false;
  }

  double _thresholdForSource(String source) {
    switch (source) {
      case 'face':
        return _faceConfidenceThreshold;
      case 'audio':
        return _audioConfidenceThreshold;
      case 'history':
        return _historyConfidence;
      default:
        return 0.0;
    }
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
