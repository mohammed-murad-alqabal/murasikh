import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/settings/models/user_settings.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _boxName = 'murassikh_settings_box';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
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
          autoLockTimeoutMinutes: map['autoLockTimeoutMinutes'] ?? 5,
          clearHistoryOnExit: map['clearHistoryOnExit'] ?? false,
          shareAnalytics: map['shareAnalytics'] ?? false,
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
      autoLockTimeoutMinutes: 5,
      clearHistoryOnExit: false,
      shareAnalytics: false,
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
