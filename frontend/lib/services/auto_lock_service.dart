import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../features/settings/models/user_settings.dart';

class AutoLockPolicy {
  static Duration timeoutFor(UserSettings settings) {
    final minutes = settings.autoLockTimeoutMinutes;
    return Duration(milliseconds: (minutes * 60 * 1000).round());
  }

  static bool shouldLock({
    required UserSettings settings,
    required DateTime lastActivity,
    required DateTime now,
    DateTime? backgroundedAt,
  }) {
    if (settings.enableBiometricAuth && backgroundedAt != null) return true;
    if (!settings.autoLockEnabled) return false;
    return now.difference(lastActivity) >= timeoutFor(settings);
  }
}

class AutoLockService {
  AutoLockService({LocalAuthentication? authenticator})
    : _authenticator = authenticator ?? LocalAuthentication();

  final LocalAuthentication _authenticator;

  Future<bool> unlock() async {
    try {
      return await _authenticator.authenticate(
        localizedReason: 'تحقق من هويتك لفتح مُرَسِّخ',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('AutoLockService error: $e');
      debugPrint('AutoLockService stackTrace: $stackTrace');
      return false;
    }
  }
}
