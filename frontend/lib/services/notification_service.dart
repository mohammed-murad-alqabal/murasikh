import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init({bool isBackground = false}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // يمكن فتح شاشة التفاصيل عند الضغط على الإشعار
      },
    );

    // Create the notification channel explicitly for the Background Service
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'murassikh_ambient_alerts',
        'تنبيهات السكينة والرفيق الروحي',
        description:
            'قناة إرسال التوجيهات القرآنية عند استشعار الانفعال في المحيط',
        importance: Importance.max,
      );
      await androidImplementation.createNotificationChannel(channel);
      if (!isBackground) {
        await androidImplementation.requestNotificationsPermission();
      }
    }
  }

  Future<void> showSpiritualAlert({
    required String emotion,
    required String tier,
    required String message,
    String? source,
    String? tafsir,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'murassikh_ambient_alerts',
          'تنبيهات السكينة والرفيق الروحي',
          channelDescription:
              'قناة إرسال التوجيهات القرآنية عند استشعار الانفعال في المحيط',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF115E59),
          styleInformation: BigTextStyleInformation(''),
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    String title;
    String body;

    if (tier == 'minimal') {
      title = '🌸 لحظة سكينة';
      body = 'تم استشعار انفعال في المحيط.. تمهل، خذ نفساً عميقاً وتذكر: لا تغضب ولك الجنة.';
    } else {
      title = source != null && source.isNotEmpty
          ? '﴿ $source ﴾'
          : 'توجيه روحي للموقف';
      body = message;
      if (tafsir != null &&
          tafsir.isNotEmpty &&
          tafsir != 'التفسير متاح عند الطلب') {
        body += '\n\nالمعنى: $tafsir';
      }
    }

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _notificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}
