import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Owns the encrypted local-data namespace for the currently active account.
///
/// Each account (including guest) receives an AES-256 Hive key stored in the
/// platform secure keystore. Purging a scope deletes both its boxes and key,
/// providing crypto-erasure for local account data.
class LocalAccountScope {
  LocalAccountScope._();

  static const String guest = 'guest';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final Map<String, List<int>> _testKeys = <String, List<int>>{};
  static final ValueNotifier<String> changes = ValueNotifier<String>(guest);
  static String _active = guest;
  static bool _legacyPurged = false;

  static const List<String> _logicalBoxes = <String>[
    'chat',
    'history',
    'offline_cache',
    'pending_feedback',
    'settings',
    'notifications',
    'daily_verse',
    'exports',
  ];

  static String get active => _active;

  static String boxName(String logicalName) =>
      'murassikh_${logicalName}_$_active';

  static Future<void> activate(String? username) async {
    if (!_legacyPurged) {
      await _purgeLegacyBoxes();
      _legacyPurged = true;
    }
    final normalized = username?.trim().toLowerCase();
    final next = normalized == null || normalized.isEmpty
        ? guest
        : 'user_${base64Url.encode(utf8.encode(normalized)).replaceAll('=', '')}';

    if (next == _active) return;

    await purge(_active);
    _active = next;
    changes.value = _active;
  }

  static Future<void> purgeActive() => purge(_active);

  static Future<HiveAesCipher> cipherForActiveScope() async {
    final key = await _getOrCreateKey(_active);
    return HiveAesCipher(key);
  }

  static Future<Box<String>> openEncryptedStringBox(String logicalName) async {
    final name = boxName(logicalName);
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);

    final cipher = await cipherForActiveScope();
    try {
      return await Hive.openBox<String>(name, encryptionCipher: cipher);
    } catch (encryptedOpenError) {
      // Migrate scoped boxes created by the previous unencrypted release. If
      // the box is not a valid legacy box, preserve the original error.
      try {
        if (Hive.isBoxOpen(name)) await Hive.box<String>(name).close();
        final legacy = await Hive.openBox<String>(name);
        final values = <dynamic, String>{
          for (final key in legacy.keys)
            if (legacy.get(key) != null) key: legacy.get(key)!,
        };
        await legacy.close();
        await Hive.deleteBoxFromDisk(name);
        final encrypted = await Hive.openBox<String>(
          name,
          encryptionCipher: cipher,
        );
        await encrypted.putAll(values);
        return encrypted;
      } catch (_) {
        Error.throwWithStackTrace(
          encryptedOpenError,
          StackTrace.current,
        );
      }
    }
  }

  static Future<void> purge(String scope) async {
    for (final logicalName in _logicalBoxes) {
      final name = 'murassikh_${logicalName}_$scope';
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box<String>(name).close();
        }
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // A missing or already-removed box is safe during logout/deletion.
      }
    }
    await _deleteKey(scope);
    _testKeys.remove(scope);
  }

  static Future<List<int>> _getOrCreateKey(String scope) async {
    try {
      final stored = await _secureStorage.read(key: _keyName(scope));
      if (stored != null) {
        try {
          final decoded = base64Url.decode(stored);
          if (decoded.length == 32) return decoded;
        } on FormatException {
          // Regenerate a valid key below; the corrupted box will fail closed.
        }
      }
      final generated = _generateKey();
      await _secureStorage.write(
        key: _keyName(scope),
        value: base64UrlEncode(generated),
      );
      return generated;
    } on MissingPluginException {
      // Flutter unit tests have no platform keystore. Never use this fallback
      // in a platform build; it exists only to keep deterministic tests safe.
      return _testKeys.putIfAbsent(scope, _generateKey);
    }
  }

  static Future<void> _deleteKey(String scope) async {
    try {
      await _secureStorage.delete(key: _keyName(scope));
    } on MissingPluginException {
      // No platform keystore is available in Flutter unit tests.
    }
  }

  static String _keyName(String scope) => 'murassikh_hive_key_$scope';

  static List<int> _generateKey() =>
      List<int>.generate(32, (_) => Random.secure().nextInt(256));

  static Future<void> _purgeLegacyBoxes() async {
    for (final name in const [
      'murassikh_chat_box',
      'murassikh_local_history',
      'cached_recommendations',
      'pending_feedback',
      'murassikh_settings_box',
      'murassikh_notifications_box',
      'daily_verse_cache',
    ]) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box<String>(name).close();
        }
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // Legacy boxes may not exist on a fresh installation.
      }
    }
  }
}
