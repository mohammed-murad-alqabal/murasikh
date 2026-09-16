import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../features/recommendation/models/recommendation_model.dart';
import 'api_service.dart';

class HistoryItem {
  final String id;
  final DateTime timestamp;
  final String inputText;
  final RecommendationModel recommendation;
  int feedback; // 0 = none, 1 = like, -1 = dislike

  HistoryItem({
    required this.id,
    required this.timestamp,
    required this.inputText,
    required this.recommendation,
    this.feedback = 0,
  });

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id:
          map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      inputText: map['input_text'] ?? '',
      recommendation: RecommendationModel.fromJson(
        map['recommendation'] is Map<String, dynamic>
            ? map['recommendation']
            : {},
      ),
      feedback: map['feedback'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'input_text': inputText,
      'recommendation': recommendation.toJson(),
      'feedback': feedback,
    };
  }
}

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  static const String baseUrl = 'http://127.0.0.1:8000/api/v1/history';
  static const String _historyBoxName = 'murassikh_local_history';
  late Box<String> _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox<String>(_historyBoxName);
      _initialized = true;
    } catch (e) {
      debugPrint("Error initializing HistoryService Hive box: $e");
    }
  }

  Future<void> saveInteraction(String text, RecommendationModel rec) async {
    await init();
    final item = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      inputText: text,
      recommendation: rec,
    );
    try {
      // 1. حفظ فوري في التخزين المحلي (Hive)
      await _box.put(item.id, jsonEncode(item.toMap()));
    } catch (e) {
      debugPrint("Error saving to local history: $e");
    }
  }

  String getFeedbackContext() {
    return "";
  }

  Future<List<HistoryItem>> getHistory() async {
    await init();
    List<HistoryItem> localItems = [];
    try {
      for (final raw in _box.values) {
        try {
          final data = jsonDecode(raw);
          localItems.add(HistoryItem.fromMap(data));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error reading local history: $e");
    }

    // محاولة المزامنة مع الخادم
    try {
      final headers = await ApiService.getHeaders();
      final response = await http
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final remoteItems = data
            .map((json) => HistoryItem.fromMap(json))
            .toList();

        // دمج السجلات المحلية مع السجلات البعيدة بدون تكرار
        final Map<String, HistoryItem> merged = {};
        for (var item in remoteItems) {
          merged[item.id] = item;
          // حفظها في التخزين المحلي للاستخدام دون إنترنت
          _box.put(item.id, jsonEncode(item.toMap()));
        }
        for (var item in localItems) {
          if (!merged.containsKey(item.id)) {
            merged[item.id] = item;
          }
        }
        final result = merged.values.toList();
        result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return result;
      }
    } catch (_) {
      // عند تعذر الاتصال بالخادم، نعتمد كلياً على التخزين المحلي
    }

    localItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return localItems;
  }

  Future<void> updateFeedback(String id, int feedbackValue) async {
    await init();
    // تحديث محلي
    try {
      final raw = _box.get(id);
      if (raw != null) {
        final data = jsonDecode(raw);
        data['feedback'] = feedbackValue;
        await _box.put(id, jsonEncode(data));
      }
    } catch (_) {}

    // تحديث في الخادم
    try {
      final headers = await ApiService.getHeaders();
      await http
          .post(
            Uri.parse('$baseUrl/feedback'),
            headers: headers,
            body: jsonEncode({'id': id, 'feedback': feedbackValue}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    await init();
    try {
      await _box.clear();
    } catch (_) {}

    try {
      final headers = await ApiService.getHeaders();
      await http.delete(Uri.parse(baseUrl), headers: headers).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
