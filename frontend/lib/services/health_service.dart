import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();

  Future<bool> requestPermissions() async {
    if (!defaultTargetPlatform.name.contains('android') &&
        !defaultTargetPlatform.name.contains('ios')) {
      return false;
    }

    await Permission.activityRecognition.request();
    await Permission.sensors.request();

    final types = [HealthDataType.HEART_RATE, HealthDataType.STEPS];

    final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

    try {
      bool? hasPermissions = await _health.hasPermissions(
        types,
        permissions: permissions,
      );
      if (hasPermissions != true) {
        bool authorized = await _health.requestAuthorization(
          types,
          permissions: permissions,
        );
        return authorized;
      }
      return true;
    } catch (e) {
      debugPrint("Health permission error: $e");
      return false;
    }
  }

  Future<double?> fetchAverageHeartRate() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: yesterday,
        endTime: now,
      );

      if (healthData.isEmpty) return null;

      double total = 0;
      for (var point in healthData) {
        // In health ^13.0.0, point.value is a NumericHealthValue
        final valueStr = point.value.toString();
        // Typically valueStr might be "NumericHealthValue{numericValue: 85}"
        // Let's extract the number robustly:
        final match = RegExp(r'([0-9]+\.?[0-9]*)').firstMatch(valueStr);
        if (match != null) {
          total += double.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }
      return total / healthData.length;
    } catch (e) {
      debugPrint("Exception in fetchAverageHeartRate: $e");
      return null;
    }
  }

  Future<String?> analyzeBiometrics() async {
    final hasPerms = await requestPermissions();
    if (!hasPerms) return null;

    final hr = await fetchAverageHeartRate();
    if (hr == null) return null;

    if (hr > 90) {
      return "يبدو أن معدل نبضات قلبك مرتفع مؤخراً (${hr.toStringAsFixed(0)} نبضة/دقيقة). حاول أن تأخذ نفساً عميقاً وتسترخي.";
    }
    return null;
  }
}
