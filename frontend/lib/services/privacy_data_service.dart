import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_service.dart';
import 'history_service.dart';
import 'local_account_scope.dart';
import 'notification_service.dart';
import 'offline_service.dart';
import 'settings_service.dart';

class ClearDataResult {
  const ClearDataResult({
    required this.localCleared,
    required this.remoteDeletionConfirmed,
  });

  final bool localCleared;
  final bool remoteDeletionConfirmed;
}

class PrivacyDataService {
  Future<Map<String, dynamic>> exportAllData() async {
    final settingsService = SettingsService();
    await settingsService.init();
    final remote = await _exportRemoteData();

    return {
      'export_version': 2,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'settings': settingsService.getSettings().toJson(),
      'remote': remote,
      'offline': await OfflineService().exportData(),
      'notifications': await NotificationService().exportStoredData(),
      'chat': await _readLogicalBox('chat'),
      'daily_verse': await _readLogicalBox('daily_verse'),
    };
  }

  /// Store the export inside an encrypted, account-scoped Hive box. The UI
  /// must not write this JSON to a permanent plaintext documents file.
  Future<String> saveEncryptedExport() async {
    final box = await LocalAccountScope.openEncryptedStringBox('exports');
    final id = 'export_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await box.put(id, jsonEncode(await exportAllData()));
    return id;
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
    } catch (_) {}
    final localHistory = await HistoryService().getHistory();
    return {
      'account': null,
      'interactions': localHistory.map((item) => item.toMap()).toList(),
      'available': false,
    };
  }

  /// Clear the interaction history and local caches without deleting the
  /// account itself. Account deletion is a separate explicit operation.
  Future<ClearDataResult> clearHistoryAndLocalCaches() async {
    var remoteDeletionConfirmed = false;
    try {
      remoteDeletionConfirmed = await HistoryService().clearHistory();
    } catch (_) {
      remoteDeletionConfirmed = false;
    }

    var localCleared = true;
    for (final clearOperation in <Future<void> Function()>[
      () => OfflineService().clearLocalData(),
      () => NotificationService().clearStoredData(),
      () => _clearLogicalBox('chat'),
      () => _clearLogicalBox('daily_verse'),
      () => _clearLogicalBox('exports'),
    ]) {
      try {
        await clearOperation();
      } catch (_) {
        localCleared = false;
      }
    }

    return ClearDataResult(
      localCleared: localCleared,
      remoteDeletionConfirmed: remoteDeletionConfirmed,
    );
  }

  /// Delete the server account first, then purge encrypted local data and keys.
  /// A failed server request leaves the local session intact so the user can
  /// retry rather than receiving a false success message.
  Future<String?> deleteAccount() => AuthService().deleteAccount();

  Future<List<dynamic>> _readLogicalBox(String logicalName) async {
    final box = await LocalAccountScope.openEncryptedStringBox(logicalName);
    final values = <dynamic>[];
    for (final raw in box.values) {
      try {
        values.add(jsonDecode(raw));
      } catch (_) {
        values.add(raw);
      }
    }
    return values;
  }

  Future<void> _clearLogicalBox(String logicalName) async {
    final box = await LocalAccountScope.openEncryptedStringBox(logicalName);
    await box.clear();
  }
}
