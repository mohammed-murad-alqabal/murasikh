class UserSettings {
  final String name;
  final String email;
  final int? age;
  final String? gender; // 'male' | 'female'
  final String? avatarUrl;
  final String preferredLanguage;
  final bool darkMode;
  final int fontSize;
  final bool notificationsEnabled;
  final String notificationStyle;
  final DateTime? lastLogin;

  // Privacy settings
  final bool hideContentInLockScreen;
  final bool enableBiometricAuth;
  final bool autoLockEnabled;
  final double autoLockTimeoutMinutes;
  final bool clearHistoryOnExit;
  final bool shareAnalytics;

  // Notification settings
  final bool notificationSound;
  final bool notificationVibrate;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool dailyReminderEnabled;
  final String dailyReminderTime;
  final bool spiritualAlertsEnabled;

  // Theme settings
  final String themeMode; // 'light', 'dark', 'system'
  final String accentColor; // hex color code

  UserSettings({
    required this.name,
    required this.email,
    this.age,
    this.gender,
    this.avatarUrl,
    this.preferredLanguage = 'ar',
    this.darkMode = false,
    this.fontSize = 16,
    this.notificationsEnabled = true,
    this.notificationStyle = 'minimal',
    this.lastLogin,
    this.hideContentInLockScreen = true,
    this.enableBiometricAuth = false,
    this.autoLockEnabled = false,
    this.autoLockTimeoutMinutes = 5.0,
    this.clearHistoryOnExit = false,
    this.shareAnalytics = false,
    this.notificationSound = true,
    this.notificationVibrate = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.dailyReminderEnabled = false,
    this.dailyReminderTime = '08:00',
    this.spiritualAlertsEnabled = true,
    this.themeMode = 'system',
    this.accentColor = '115E59',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'age': age,
      'gender': gender,
      'avatarUrl': avatarUrl,
      'preferredLanguage': preferredLanguage,
      'darkMode': darkMode,
      'fontSize': fontSize,
      'notificationsEnabled': notificationsEnabled,
      'notificationStyle': notificationStyle,
      'lastLogin': lastLogin?.toIso8601String(),
      'hideContentInLockScreen': hideContentInLockScreen,
      'enableBiometricAuth': enableBiometricAuth,
      'autoLockEnabled': autoLockEnabled,
      'autoLockTimeoutMinutes': autoLockTimeoutMinutes,
      'clearHistoryOnExit': clearHistoryOnExit,
      'shareAnalytics': shareAnalytics,
      'notificationSound': notificationSound,
      'notificationVibrate': notificationVibrate,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderTime': dailyReminderTime,
      'spiritualAlertsEnabled': spiritualAlertsEnabled,
      'themeMode': themeMode,
      'accentColor': accentColor,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      avatarUrl: json['avatarUrl'],
      preferredLanguage: json['preferredLanguage'] ?? 'ar',
      darkMode: json['darkMode'] ?? false,
      fontSize: json['fontSize'] ?? 16,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      notificationStyle: json['notificationStyle'] ?? 'minimal',
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'] as String)
          : null,
      hideContentInLockScreen: json['hideContentInLockScreen'] ?? true,
      enableBiometricAuth: json['enableBiometricAuth'] ?? false,
      autoLockEnabled: json['autoLockEnabled'] ?? false,
      autoLockTimeoutMinutes:
          (json['autoLockTimeoutMinutes'] as num?)?.toDouble() ?? 5.0,
      clearHistoryOnExit: json['clearHistoryOnExit'] ?? false,
      shareAnalytics: json['shareAnalytics'] ?? false,
      notificationSound: json['notificationSound'] ?? true,
      notificationVibrate: json['notificationVibrate'] ?? true,
      quietHoursEnabled: json['quietHoursEnabled'] ?? false,
      quietHoursStart: json['quietHoursStart'] ?? '22:00',
      quietHoursEnd: json['quietHoursEnd'] ?? '07:00',
      dailyReminderEnabled: json['dailyReminderEnabled'] ?? false,
      dailyReminderTime: json['dailyReminderTime'] ?? '08:00',
      spiritualAlertsEnabled: json['spiritualAlertsEnabled'] ?? true,
      themeMode: json['themeMode'] ?? 'system',
      accentColor: json['accentColor'] ?? '115E59',
    );
  }

  UserSettings copyWith({
    String? name,
    String? email,
    Object? age = _sentinel,
    Object? gender = _sentinel,
    String? avatarUrl,
    String? preferredLanguage,
    bool? darkMode,
    int? fontSize,
    bool? notificationsEnabled,
    String? notificationStyle,
    DateTime? lastLogin,
    bool? hideContentInLockScreen,
    bool? enableBiometricAuth,
    bool? autoLockEnabled,
    double? autoLockTimeoutMinutes,
    bool? clearHistoryOnExit,
    bool? shareAnalytics,
    bool? notificationSound,
    bool? notificationVibrate,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? dailyReminderEnabled,
    String? dailyReminderTime,
    bool? spiritualAlertsEnabled,
    String? themeMode,
    String? accentColor,
  }) {
    return UserSettings(
      name: name ?? this.name,
      email: email ?? this.email,
      age: age == _sentinel ? this.age : age as int?,
      gender: gender == _sentinel ? this.gender : gender as String?,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationStyle: notificationStyle ?? this.notificationStyle,
      lastLogin: lastLogin ?? this.lastLogin,
      hideContentInLockScreen:
          hideContentInLockScreen ?? this.hideContentInLockScreen,
      enableBiometricAuth: enableBiometricAuth ?? this.enableBiometricAuth,
      autoLockEnabled: autoLockEnabled ?? this.autoLockEnabled,
      autoLockTimeoutMinutes:
          autoLockTimeoutMinutes ?? this.autoLockTimeoutMinutes,
      clearHistoryOnExit: clearHistoryOnExit ?? this.clearHistoryOnExit,
      shareAnalytics: shareAnalytics ?? this.shareAnalytics,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationVibrate: notificationVibrate ?? this.notificationVibrate,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      spiritualAlertsEnabled:
          spiritualAlertsEnabled ?? this.spiritualAlertsEnabled,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

// Sentinel for nullable copyWith fields
const _sentinel = Object();
