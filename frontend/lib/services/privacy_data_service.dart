import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'history_service.dart';
import 'notification_service.dart';
import 'offline_service.dart';
import 'settings_service.dart';

class PrivacyDataService {
  static const String _chatBoxName = 'murassikh_chat_box';
  static const String _dailyVerseBoxName = 'daily_verse_cache';

  Future<Map<String, dynamic>> exportAllData() async {
    final settingsService = SettingsService();
    await settingsService.init();
    final remote = await _exportRemoteData();

    return {
      'export_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'settings': settingsService.getSettings().toJson(),
      'remote': remote,
      'offline': await OfflineService().exportData(),
      'notifications': await NotificationService().exportStoredData(),
      'chat': await _readStringBox(_chatBoxName),
      'daily_verse': await _readStringBox(_dailyVerseBoxName),
    };
  }

  Future<Map<String, dynamic>> _exportRemoteData() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/auth/export'),
            headers: await ApiService.getHeaders(),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error exporting remote data: $e');
    }
    return {
      'account': null,
      'interactions': await HistoryService().getHistory(),
      'available': false,
    };
  }

  Future<bool> clearAllUserData() async {
    final remoteCleared = await HistoryService().clearHistory();
    if (!remoteCleared) return false;

    try {
      await OfflineService().clearLocalData();
      await NotificationService().clearStoredData();
      await _clearBox(_chatBoxName);
      await _clearBox(_dailyVerseBoxName);
      return true;
    } catch (e) {
      debugPrint('Error clearing all user data: $e');
      return false;
    }
  }

  Future<List<dynamic>> _readStringBox(String name) async {
    final box = await _openStringBox(name);
    final values = <dynamic>[];
    for (final raw in box.values) {
      try {
        values.add(jsonDecode(raw));
      } catch (e) {
        debugPrint('Error decoding JSON for box value: $e');
        values.add(raw);
      }
    }
    return values;
  }

  Future<void> _clearBox(String name) async {
    final box = await _openStringBox(name);
    await box.clear();
  }

  Future<Box<String>> _openStringBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    return Hive.openBox<String>(name);
  }
}
