import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../features/recommendation/models/recommendation_model.dart';

/// خدمة العمل بدون إنترنت (Offline-First)
/// تتولى:
/// 1. اكتشاف حالة الاتصال
/// 2. تخزين التوصيات الأخيرة محلياً
/// 3. تأجيل التقييمات حتى عودة الإنترنت
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _cacheBoxName = 'cached_recommendations';
  static const String _pendingFeedbackBox = 'pending_feedback';
  static const int _maxCacheSize = 20; // نحتفظ بآخر 20 توصية

  late Box<String> _cacheBox;
  late Box<String> _feedbackBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _cacheBox = await Hive.openBox<String>(_cacheBoxName);
    _feedbackBox = await Hive.openBox<String>(_pendingFeedbackBox);
    _initialized = true;
  }

  // ============================================================
  //  فحص حالة الاتصال
  // ============================================================

  /// هل الجهاز متصل بالإنترنت الآن؟
  Future<bool> isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Stream مستمر لحالة الاتصال
  Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }

  // ============================================================
  //  التخزين المحلي للتوصيات
  // ============================================================

  /// احفظ توصية في التخزين المحلي مرتبطة بنص المدخل
  Future<void> cacheRecommendation(
    String inputText,
    RecommendationModel rec,
  ) async {
    await init();
    // المفتاح: أول 50 حرف من النص لتجنب التكرار
    final key = inputText.length > 50 ? inputText.substring(0, 50) : inputText;
    final value = jsonEncode({
      'input': inputText,
      'timestamp': DateTime.now().toIso8601String(),
      'recommendation': rec.toJson(),
    });
    await _cacheBox.put(key, value);

    // حذف الأقدم إذا تجاوز الحد
    if (_cacheBox.length > _maxCacheSize) {
      final keys = _cacheBox.keys.toList();
      await _cacheBox.delete(keys.first);
    }
  }

  /// جلب توصية محلية بناءً على الحالة العاطفية أو أي نص
  RecommendationModel? getCachedRecommendation(String emotion) {
    for (final key in _cacheBox.keys) {
      final raw = _cacheBox.get(key);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final rec = RecommendationModel.fromJson(
          data['recommendation'] as Map<String, dynamic>,
        );
        if (rec.emotion == emotion) return rec;
      } catch (_) {}
    }
    return null;
  }

  /// جلب أحدث توصية مخزنة (أي كانت) كاحتياط أخير
  RecommendationModel? getLatestCachedRecommendation() {
    if (_cacheBox.isEmpty) return null;
    final keys = _cacheBox.keys.toList();
    final raw = _cacheBox.get(keys.last);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return RecommendationModel.fromJson(
        data['recommendation'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// آية ثابتة تُعرض عند عدم وجود أي بيانات محلية
  RecommendationModel get fallbackRecommendation => RecommendationModel(
    emotion: 'طبيعي',
    confidence: 1.0,
    tier: 'full',
    message: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    source: 'سورة الرعد: 28',
    tafsir: 'ذكر الله سبحانه هو مفتاح الطمأنينة والراحة النفسية.',
  );

  // ============================================================
  //  تأجيل التقييمات (Pending Feedback Sync)
  // ============================================================

  /// احفظ تقييماً لإرساله لاحقاً عند عودة الإنترنت
  Future<void> savePendingFeedback(String id, int feedbackValue) async {
    await init();
    final key = 'fb_${DateTime.now().millisecondsSinceEpoch}';
    await _feedbackBox.put(
      key,
      jsonEncode({'id': id, 'feedback': feedbackValue}),
    );
  }

  /// جلب قائمة التقييمات المؤجلة
  List<Map<String, dynamic>> getPendingFeedbacks() {
    return _feedbackBox.values
        .map((raw) {
          try {
            return jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> exportData() async {
    await init();
    final cachedRecommendations = <dynamic>[];
    for (final raw in _cacheBox.values) {
      try {
        cachedRecommendations.add(jsonDecode(raw));
      } catch (_) {}
    }
    return {
      'cached_recommendations': cachedRecommendations,
      'pending_feedback': getPendingFeedbacks(),
    };
  }

  Future<void> clearLocalData() async {
    await init();
    await _cacheBox.clear();
    await _feedbackBox.clear();
  }

  /// مسح التقييمات المؤجلة بعد إرسالها بنجاح
  Future<void> clearPendingFeedbacks() async {
    await _feedbackBox.clear();
  }
}
