import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../features/recommendation/models/recommendation_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Background isolate audio sampling loop
  final audioRecorder = AudioRecorder();
  final apiService = ApiService();
  final notificationService = NotificationService();
  await notificationService.init();

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        try {
          if (await audioRecorder.hasPermission()) {
            final tempDir = await getTemporaryDirectory();
            final samplePath =
                '${tempDir.path}/ambient_sample_bg_${DateTime.now().millisecondsSinceEpoch}.wav';

            await audioRecorder.start(
              const RecordConfig(
                encoder: AudioEncoder.wav,
                sampleRate: 16000,
                numChannels: 1,
              ),
              path: samplePath,
            );

            await Future.delayed(const Duration(seconds: 3));
            final recordedPath = await audioRecorder.stop();

            if (recordedPath != null && File(recordedPath).existsSync()) {
              try {
                final rec = await apiService.analyzeAudio(recordedPath);
                if (rec.emotion != 'طبيعي' && rec.emotion != 'بشاشة') {
                  await notificationService.showSpiritualAlert(
                    emotion: rec.emotion,
                    tier: rec.tier,
                    message: rec.message,
                    source: rec.source,
                    tafsir: rec.tafsir,
                  );
                }
              } catch (_) {
              } finally {
                try {
                  File(recordedPath).deleteSync();
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }
    }
  });
}

class AmbientListeningService extends ChangeNotifier {
  static final AmbientListeningService _instance =
      AmbientListeningService._internal();
  factory AmbientListeningService() => _instance;
  AmbientListeningService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  bool _isListening = false;
  final bool _isSampling = false;
  Timer? _cycleTimer;

  String _errorMessage = '';
  String _liveSpeech = '';
  RecommendationModel? _latestRecommendation;

  bool get isListening => _isListening;
  String get errorMessage => _errorMessage;
  String get liveSpeech => _liveSpeech;
  RecommendationModel? get latestRecommendation => _latestRecommendation;

  Future<bool> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'murassikh_ambient_alerts',
        initialNotificationTitle: 'مُرَسِّخ',
        initialNotificationContent: 'حارس السكينة يستمع بهدوء...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (ServiceInstance service) => false,
      ),
    );
    return true;
  }

  Future<void> startListening() async {
    if (_isListening) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _errorMessage = "يرجى منح إذن استخدام المايكروفون ليعمل حارس السكينة.";
        notifyListeners();
        return;
      }

      final service = FlutterBackgroundService();
      await service.startService();

      _isListening = true;
      _liveSpeech = "بدأ حارس السكينة في مراقبة الأجواء (يعمل في الخلفية)...";
      notifyListeners();
    } catch (e) {
      debugPrint("Error starting Ambient Guardian: $e");
      _isListening = false;
      _errorMessage = "تعذر بدء حارس السكينة: $e";
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    _liveSpeech = "تم إيقاف حارس السكينة";
    notifyListeners();
  }

  /// تجربة فورية لاختبار عمل الإشعار والتنبيه
  Future<void> testTriggerAlert() async {
    final testRec = RecommendationModel(
      emotion: 'قلق أو توتر',
      confidence: 0.95,
      tier: 'moderate',
      message: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ. توقف لحظة واذكر ربك يهدأ قلبك.',
      source: 'سورة الرعد: آية 28',
      tafsir: 'ذكر الله سبحانه هو أعظم حصن وملاذ للطمأنينة ودفع القلق.',
    );

    _latestRecommendation = testRec;
    _liveSpeech = "تم إرسال إشعار سكينة تجريبي للتأكد من فاعلية النظام";
    notifyListeners();

    await _notificationService.showSpiritualAlert(
      emotion: testRec.emotion,
      tier: testRec.tier,
      message: testRec.message,
      source: testRec.source,
      tafsir: testRec.tafsir,
    );
  }
}
