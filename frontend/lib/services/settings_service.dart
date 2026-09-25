import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/settings/models/user_settings.dart';
import 'local_account_scope.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late Box<String> _box;
  String? _scope;

  Future<void> init() async {
    final scope = LocalAccountScope.active;
    final boxName = LocalAccountScope.boxName('settings');
    if (_scope == scope && Hive.isBoxOpen(boxName)) {
      _box = Hive.box<String>(boxName);
      return;
    }
    if (_scope != null && _box.isOpen) await _box.close();
    _box = await LocalAccountScope.openEncryptedStringBox('settings');
    _scope = scope;
  }

  UserSettings getSettings() {
    final raw = _box.get('user_settings');
    if (raw != null) {
      try {
        final map = jsonDecode(raw);
        return UserSettings(
          name: map['name'] ?? 'مستخدم مُرَسِّخ',
          age: map['age'] as int?,
          gender: map['gender'] as String?,
          email: map['email'] ?? '',
          preferredLanguage: map['preferredLanguage'] ?? 'ar',
          darkMode: map['darkMode'] ?? false,
          fontSize: map['fontSize'] ?? 16,
          notificationsEnabled: map['notificationsEnabled'] ?? true,
          notificationStyle: map['notificationStyle'] ?? 'minimal',
          themeMode: map['themeMode'] ?? 'system',
          accentColor: map['accentColor'] ?? '115E59',
          hideContentInLockScreen: map['hideContentInLockScreen'] ?? true,
          enableBiometricAuth: map['enableBiometricAuth'] ?? false,
          autoLockEnabled: map['autoLockEnabled'] ?? false,
          autoLockTimeoutMinutes:
              (map['autoLockTimeoutMinutes'] as num?)?.toDouble() ?? 5.0,
          clearHistoryOnExit: map['clearHistoryOnExit'] ?? false,
          shareAnalytics: map['shareAnalytics'] ?? false,
          allowSensitiveContext: map['allowSensitiveContext'] ?? false,
          notificationSound: map['notificationSound'] ?? true,
          notificationVibrate: map['notificationVibrate'] ?? true,
          quietHoursEnabled: map['quietHoursEnabled'] ?? false,
          quietHoursStart: map['quietHoursStart'] ?? '22:00',
          quietHoursEnd: map['quietHoursEnd'] ?? '06:00',
          dailyReminderEnabled: map['dailyReminderEnabled'] ?? true,
          dailyReminderTime: map['dailyReminderTime'] ?? '20:00',
          spiritualAlertsEnabled: map['spiritualAlertsEnabled'] ?? true,
        );
      } catch (e) {
        debugPrint('Error parsing settings: $e');
      }
    }

    // Default settings
    return UserSettings(
      name: 'مستخدم مُرَسِّخ',
      email: '',
      preferredLanguage: 'ar',
      darkMode: false,
      fontSize: 16,
      notificationsEnabled: true,
      notificationStyle: 'minimal',
      themeMode: 'system',
      accentColor: '115E59',
      hideContentInLockScreen: true,
      enableBiometricAuth: false,
      autoLockEnabled: false,
      autoLockTimeoutMinutes: 5.0,
      clearHistoryOnExit: false,
      shareAnalytics: false,
      allowSensitiveContext: false,
    );
  }

  Future<void> saveSettings(UserSettings settings) async {
    final map = {
      'name': settings.name,
      'email': settings.email,
      'age': settings.age,
      'gender': settings.gender,
      'preferredLanguage': settings.preferredLanguage,
      'darkMode': settings.darkMode,
      'fontSize': settings.fontSize,
      'notificationsEnabled': settings.notificationsEnabled,
      'notificationStyle': settings.notificationStyle,
      'themeMode': settings.themeMode,
      'accentColor': settings.accentColor,
      'hideContentInLockScreen': settings.hideContentInLockScreen,
      'enableBiometricAuth': settings.enableBiometricAuth,
      'autoLockEnabled': settings.autoLockEnabled,
      'autoLockTimeoutMinutes': settings.autoLockTimeoutMinutes,
      'clearHistoryOnExit': settings.clearHistoryOnExit,
      'shareAnalytics': settings.shareAnalytics,
      'allowSensitiveContext': settings.allowSensitiveContext,
      'notificationSound': settings.notificationSound,
      'notificationVibrate': settings.notificationVibrate,
      'quietHoursEnabled': settings.quietHoursEnabled,
      'quietHoursStart': settings.quietHoursStart,
      'quietHoursEnd': settings.quietHoursEnd,
      'dailyReminderEnabled': settings.dailyReminderEnabled,
      'dailyReminderTime': settings.dailyReminderTime,
      'spiritualAlertsEnabled': settings.spiritualAlertsEnabled,
    };
    await _box.put('user_settings', jsonEncode(map));
  }
}
