import 'package:flutter_test/flutter_test.dart';

import 'package:murassikh_app/features/settings/models/user_settings.dart';
import 'package:murassikh_app/services/auto_lock_service.dart';

void main() {
  final baseTime = DateTime(2026, 1, 1, 12);

  UserSettings settings({
    bool autoLockEnabled = true,
    bool biometric = false,
    double timeout = 5.0,
  }) {
    return UserSettings(
      name: 'test',
      email: 'test@example.com',
      autoLockEnabled: autoLockEnabled,
      enableBiometricAuth: biometric,
      autoLockTimeoutMinutes: timeout,
    );
  }

  test('converts half a minute setting to a 30-second duration', () {
    expect(
      AutoLockPolicy.timeoutFor(settings(timeout: 0.5)),
      const Duration(seconds: 30),
    );
  });

  test('does not lock before the configured timeout', () {
    expect(
      AutoLockPolicy.shouldLock(
        settings: settings(timeout: 5),
        lastActivity: baseTime,
        now: baseTime.add(const Duration(minutes: 4, seconds: 59)),
      ),
      isFalse,
    );
  });

  test('locks at the configured timeout', () {
    expect(
      AutoLockPolicy.shouldLock(
        settings: settings(timeout: 0.5),
        lastActivity: baseTime,
        now: baseTime.add(const Duration(seconds: 30)),
      ),
      isTrue,
    );
  });

  test('biometric setting locks after returning from background', () {
    expect(
      AutoLockPolicy.shouldLock(
        settings: settings(autoLockEnabled: false, biometric: true),
        lastActivity: baseTime,
        now: baseTime.add(const Duration(seconds: 1)),
        backgroundedAt: baseTime,
      ),
      isTrue,
    );
  });

  test('disabled settings do not lock', () {
    expect(
      AutoLockPolicy.shouldLock(
        settings: settings(autoLockEnabled: false),
        lastActivity: baseTime,
        now: baseTime.add(const Duration(days: 1)),
      ),
      isFalse,
    );
  });
}
