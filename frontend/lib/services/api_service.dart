import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/recommendation/models/recommendation_model.dart';
import 'history_service.dart';
import 'offline_service.dart';
import 'settings_service.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  /// جلب التوصية مع دعم Offline-First
  Future<RecommendationModel> getRecommendation(
    String text, {
    bool forceOffline = false,
  }) async {
    final offlineService = OfflineService();
    await offlineService.init();

    final isConnected = forceOffline
        ? false
        : await offlineService.isConnected();

    if (isConnected) {
      try {
        final rec = await _fetchFromServer(text);
        // خزّن النتيجة محلياً لاستخدامها عند انقطاع الإنترنت
        await offlineService.cacheRecommendation(text, rec);
        await HistoryService().saveInteraction(text, rec);
        // أرسل أي تقييمات مؤجلة كانت متراكمة
        _syncPendingFeedbacks(offlineService);
        return rec;
      } catch (e) {
        // إذا فشل الخادم، استخدم النسخة المحلية
        final rec = _getOfflineRecommendation(offlineService, text);
        await HistoryService().saveInteraction(text, rec);
        return rec;
      }
    } else {
      final rec = _getOfflineRecommendation(offlineService, text);
      await HistoryService().saveInteraction(text, rec);
      return rec;
    }
  }

  /// إرسال تقييم مع دعم Offline (تأجيل عند انقطاع الإنترنت)
  Future<void> submitFeedback(String id, int feedbackValue) async {
    final offlineService = OfflineService();
    await offlineService.init();
    final isConnected = await offlineService.isConnected();

    if (isConnected) {
      try {
        await _sendFeedbackToServer(id, feedbackValue);
        // مزامنة التقييمات المؤجلة القديمة
        _syncPendingFeedbacks(offlineService);
      } catch (_) {
        // في حالة فشل الإرسال، احفظه مؤجلاً
        await offlineService.savePendingFeedback(id, feedbackValue);
      }
    } else {
      await offlineService.savePendingFeedback(id, feedbackValue);
    }
  }

  // ============================================================
  //  الدوال الداخلية
  // ============================================================

  Future<RecommendationModel> _fetchFromServer(String text) async {
    final settingsService = SettingsService();
    await settingsService.init();
    final settings = settingsService.getSettings();

    Map<String, dynamic>? userContext;
    if (settings.age != null || settings.gender != null) {
      userContext = {
        if (settings.age != null) 'age': settings.age,
        if (settings.gender != null) 'gender': settings.gender,
      };
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/analyze'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'text': text, 'user_context': userContext}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
      return RecommendationModel.fromJson(decodedData);
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  RecommendationModel _getOfflineRecommendation(
    OfflineService offlineService,
    String text,
  ) {
    // 1. ابحث عن نفس الحالة العاطفية في الكاش
    // (نجرب الكلمات الشائعة في النص)
    final emotions = ['غضب', 'حزن', 'قلق', 'فرح', 'يأس', 'توتر'];
    for (final emotion in emotions) {
      if (text.contains(emotion)) {
        final cached = offlineService.getCachedRecommendation(emotion);
        if (cached != null) return cached;
      }
    }
    // 2. إرجاع أحدث توصية مخزنة
    final latest = offlineService.getLatestCachedRecommendation();
    if (latest != null) return latest;
    // 3. الاحتياط الأخير: آية ثابتة
    return offlineService.fallbackRecommendation;
  }

  Future<void> _sendFeedbackToServer(String id, int feedbackValue) async {
    await http
        .post(
          Uri.parse('$baseUrl/history/feedback'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id, 'feedback': feedbackValue}),
        )
        .timeout(const Duration(seconds: 5));
  }

  /// مزامنة التقييمات المؤجلة في الخلفية
  void _syncPendingFeedbacks(OfflineService offlineService) async {
    final pending = offlineService.getPendingFeedbacks();
    if (pending.isEmpty) return;
    try {
      for (final fb in pending) {
        await _sendFeedbackToServer(
          fb['id'].toString(),
          (fb['feedback'] as num).toInt(),
        );
      }
      await offlineService.clearPendingFeedbacks();
    } catch (_) {
      // تُترك المزامنة للمحاولة القادمة
    }
  }

  /// إرسال مقطع صوتي لتحليله
  Future<RecommendationModel> analyzeAudio(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/analyze-audio'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 15),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
      final rec = RecommendationModel.fromJson(decodedData);
      await HistoryService().saveInteraction('رسالة صوتية', rec);
      return rec;
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }
}
