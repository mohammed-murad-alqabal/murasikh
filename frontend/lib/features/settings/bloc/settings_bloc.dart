import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/user_settings.dart';
import '../../../../services/settings_service.dart';

// Events
abstract class SettingsEvent {}

class LoadSettings extends SettingsEvent {}

class UpdateSettings extends SettingsEvent {
  final UserSettings settings;
  UpdateSettings({required this.settings});
}

class UpdateTheme extends SettingsEvent {
  final bool darkMode;
  UpdateTheme({required this.darkMode});
}

class UpdateLanguage extends SettingsEvent {
  final String language;
  UpdateLanguage({required this.language});
}

class UpdateFontSize extends SettingsEvent {
  final int fontSize;
  UpdateFontSize({required this.fontSize});
}

class UpdatePrivacySettings extends SettingsEvent {
  final bool? hideContentInLockScreen;
  final bool? enableBiometricAuth;
  final bool? autoLockEnabled;
  final double? autoLockTimeoutMinutes;
  final bool? clearHistoryOnExit;
  final bool? shareAnalytics;

  UpdatePrivacySettings({
    this.hideContentInLockScreen,
    this.enableBiometricAuth,
    this.autoLockEnabled,
    this.autoLockTimeoutMinutes,
    this.clearHistoryOnExit,
    this.shareAnalytics,
  });
}

class UpdateNotificationsSettings extends SettingsEvent {
  final bool? notificationsEnabled;
  final bool? notificationSound;
  final bool? notificationVibrate;
  final bool? quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final bool? dailyReminderEnabled;
  final String? dailyReminderTime;
  final bool? spiritualAlertsEnabled;

  UpdateNotificationsSettings({
    this.notificationsEnabled,
    this.notificationSound,
    this.notificationVibrate,
    this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.dailyReminderEnabled,
    this.dailyReminderTime,
    this.spiritualAlertsEnabled,
  });
}

class UpdateThemeSettings extends SettingsEvent {
  final String? themeMode;
  final String? accentColor;

  UpdateThemeSettings({this.themeMode, this.accentColor});
}

class ClearHistory extends SettingsEvent {}

// State
class SettingsState {
  final UserSettings userSettings;
  final bool isLoading;

  SettingsState({UserSettings? userSettings, bool? isLoading})
    : userSettings = userSettings ?? UserSettings(name: '', email: ''),
      isLoading = isLoading ?? false;

  SettingsState copyWith({UserSettings? userSettings, bool? isLoading}) {
    return SettingsState(
      userSettings: userSettings ?? this.userSettings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateSettings>(_onUpdateSettings);
    on<UpdateTheme>(_onUpdateTheme);
    on<UpdateLanguage>(_onUpdateLanguage);
    on<UpdateFontSize>(_onUpdateFontSize);
    on<UpdatePrivacySettings>(_onUpdatePrivacySettings);
    on<UpdateNotificationsSettings>(_onUpdateNotificationsSettings);
    on<UpdateThemeSettings>(_onUpdateThemeSettings);
    on<ClearHistory>(_onClearHistory);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final userSettings = SettingsService().getSettings();
    emit(state.copyWith(userSettings: userSettings, isLoading: false));
  }

  Future<void> _onUpdateSettings(UpdateSettings event, Emitter<SettingsState> emit) async {
    await SettingsService().saveSettings(event.settings);
    emit(state.copyWith(userSettings: event.settings));
  }

  Future<void> _onUpdateTheme(UpdateTheme event, Emitter<SettingsState> emit) async {
    final updatedSettings = state.userSettings.copyWith(
      darkMode: event.darkMode,
    );
    await SettingsService().saveSettings(updatedSettings);
    emit(state.copyWith(userSettings: updatedSettings));
  }

  Future<void> _onUpdateLanguage(UpdateLanguage event, Emitter<SettingsState> emit) async {
    final updatedSettings = state.userSettings.copyWith(
      preferredLanguage: event.language,
    );
    await SettingsService().saveSettings(updatedSettings);
    emit(state.copyWith(userSettings: updatedSettings));
  }

  Future<void> _onUpdateFontSize(UpdateFontSize event, Emitter<SettingsState> emit) async {
    final updatedSettings = state.userSettings.copyWith(
      fontSize: event.fontSize,
    );
    await SettingsService().saveSettings(updatedSettings);
    emit(state.copyWith(userSettings: updatedSettings));
  }

  Future<void> _onUpdatePrivacySettings(
    UpdatePrivacySettings event,
    Emitter<SettingsState> emit,
  ) async {
    final updatedSettings = state.userSettings.copyWith(
      hideContentInLockScreen: event.hideContentInLockScreen,
      enableBiometricAuth: event.enableBiometricAuth,
      autoLockEnabled: event.autoLockEnabled,
      autoLockTimeoutMinutes: event.autoLockTimeoutMinutes?.toInt(),
      clearHistoryOnExit: event.clearHistoryOnExit,
      shareAnalytics: event.shareAnalytics,
    );
    await SettingsService().saveSettings(updatedSettings);
    emit(state.copyWith(userSettings: updatedSettings));
  }

  Future<void> _onUpdateNotificationsSettings(
    UpdateNotificationsSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final updatedSettings = state.userSettings.copyWith(
      notificationsEnabled: event.notificationsEnabled,
      notificationSound: event.notificationSound,
      notificationVibrate: event.notificationVibrate,
      quietHoursEnabled: event.quietHoursEnabled,
      quietHoursStart: event.quietHoursStart,
      quietHoursEnd: event.quietHoursEnd,
      dailyReminderEnabled: event.dailyReminderEnabled,
      dailyReminderTime: event.dailyReminderTime,
      spiritualAlertsEnabled: event.spiritualAlertsEnabled,
    );
    await SettingsService().saveSettings(updatedSettings);
    emit(state.copyWith(userSettings: updatedSettings));
  }

  Future<void> _onUpdateThemeSettings(
    UpdateThemeSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final updatedSettings = state.userSettings.copyWith(
      themeMode: event.themeMode,
      accentColor: event.accentColor,
    );
    await SettingsService().saveSettings(updatedSettings);
    emit(state.copyWith(userSettings: updatedSettings));
  }

  void _onClearHistory(ClearHistory event, Emitter<SettingsState> emit) {
    emit(state);
  }
}
