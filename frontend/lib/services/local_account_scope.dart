import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Owns the local-data namespace for the currently active account.
///
/// The namespace is an isolation boundary, not an encryption mechanism. Data
/// is purged before switching between accounts so a later user cannot inherit
/// the previous user's chat, history, cache, or pending feedback.
class LocalAccountScope {
  LocalAccountScope._();

  static const String guest = 'guest';
  static String _active = guest;
  static bool _legacyPurged = false;

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
  }

  static Future<void> purgeActive() => purge(_active);

  static Future<void> purge(String scope) async {
    for (final logicalName in const [
      'chat',
      'history',
      'offline_cache',
      'pending_feedback',
    ]) {
      final name = 'murassikh_${logicalName}_$scope';
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box<String>(name).close();
        }
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {
        // A missing or already-removed box is safe to ignore during logout.
      }
    }
  }

  static Future<void> _purgeLegacyBoxes() async {
    for (final name in const [
      'murassikh_chat_box',
      'murassikh_local_history',
      'cached_recommendations',
      'pending_feedback',
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
