import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../features/notifications/models/app_notification.dart';
import 'settings_service.dart';
import 'api_service.dart';
import 'home_context_service.dart';

class NotificationSchedulePolicy {
  static DateTime nextInstanceOfTime(DateTime now, int hour, int minute) {
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static bool isWithinQuietHours(DateTime now, String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length != 2 || endParts.length != 2) return false;
    final startMinutes =
        (int.tryParse(startParts[0]) ?? 0) * 60 +
        (int.tryParse(startParts[1]) ?? 0);
    final endMinutes =
        (int.tryParse(endParts[0]) ?? 0) * 60 +
        (int.tryParse(endParts[1]) ?? 0);
    final currentMinutes = now.hour * 60 + now.minute;

    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _boxName = 'murassikh_notifications_box';
  Box<String>? _box;
  bool _initialized = false;

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> init({bool isBackground = false}) async {
    if (_initialized) return;

    // 1. Initialize Hive for persistence
    try {
      _box = await Hive.openBox<String>(_boxName);
      _loadFromHive();
    } catch (e) {
      debugPrint('Error opening notifications box: $e');
    }

    // 2. Initialize Timezones
    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('Error initializing timezones: $e');
    }

    // 3. Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Here we can navigate to the notification center
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      // Channel for ambient/immediate alerts
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'murassikh_alerts',
        'تنبيهات السكينة والرفيق الروحي',
        description: 'قناة إرسال التوجيهات القرآنية الفورية',
        importance: Importance.max,
      );

      // Channel for daily reminders
      const AndroidNotificationChannel dailyChannel =
          AndroidNotificationChannel(
            'murassikh_daily',
            'التذكير اليومي',
            description: 'قناة التذكير اليومي والورد القرآني',
            importance: Importance.defaultImportance,
          );

      await androidImplementation.createNotificationChannel(channel);
      await androidImplementation.createNotificationChannel(dailyChannel);

      if (!isBackground) {
        await androidImplementation.requestNotificationsPermission();
      }
    }

    _initialized = true;
    _scheduleDailyRemindersIfNeeded();
  }

  void _loadFromHive() {
    if (_box == null) return;
    _notifications.clear();
    for (final raw in _box!.values) {
      try {
        _notifications.add(AppNotification.fromJson(raw));
      } catch (e) {
        debugPrint('Error parsing notification: $e');
      }
    }
    _sortNotifications();
    notifyListeners();
  }

  void _sortNotifications() {
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _saveToHive(AppNotification notification) async {
    try {
      await _box?.put(notification.id, notification.toJson());
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  Future<void> addAndShowNotification({
    required String title,
    required String body,
    required String type,
    String? payload,
    String channelId = 'murassikh_alerts',
  }) async {
    final settings = SettingsService().getSettings();
    if (settings.quietHoursEnabled &&
        NotificationSchedulePolicy.isWithinQuietHours(
          DateTime.now(),
          settings.quietHoursStart,
          settings.quietHoursEnd,
        )) {
      return;
    }

    // 1. Anti-spam/Throttling check (for 'face' and 'ambient' types)
    if (type == 'ambient' || type == 'face') {
      final now = DateTime.now();
      final recentSimilar = _notifications
          .where(
            (n) =>
                n.type == type &&
                n.title == title &&
                now.difference(n.timestamp).inMinutes < 60,
          )
          .toList();

      if (recentSimilar.isNotEmpty) {
        debugPrint('Throttling notification: $title');
        return; // Skip showing to avoid spam
      }
    }

    // 2. Create and save internally
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      payload: payload,
    );

    _notifications.add(notification);
    _sortNotifications();
    await _saveToHive(notification);
    notifyListeners();

    // 3. Show native notification
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelId == 'murassikh_daily'
              ? 'التذكير اليومي'
              : 'تنبيهات السكينة والرفيق الروحي',
          importance: channelId == 'murassikh_daily'
              ? Importance.defaultImportance
              : Importance.max,
          priority: channelId == 'murassikh_daily'
              ? Priority.defaultPriority
              : Priority.high,
          showWhen: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF115E59),
          styleInformation: BigTextStyleInformation(''),
        );

    await _notificationsPlugin.show(
      id: notification.id.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  // --- Methods used by existing services ---

  Future<void> showSpiritualAlert({
    required String emotion,
    required String tier,
    required String message,
    String? source,
    String? tafsir,
    String type = 'ambient', // can be 'face' or 'ambient'
  }) async {
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

    await addAndShowNotification(title: title, body: body, type: type);
  }

  // --- Notification Center Management ---

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveToHive(_notifications[index]);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        await _saveToHive(n);
      }
    }
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    try {
      await _box?.delete(id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    try {
      await _box?.clear();
    } catch (_) {}
    notifyListeners();
  }

  Future<List<String>> exportStoredData() async {
    _box ??= await Hive.openBox<String>(_boxName);
    return _box!.values.toList();
  }

  Future<void> clearStoredData() async {
    _box ??= await Hive.openBox<String>(_boxName);
    _notifications.clear();
    await _box!.clear();
    notifyListeners();
  }

  // --- Scheduling ---

  Future<void> scheduleContextualDailyReminder() async {
    final settings = SettingsService().getSettings();
    if (!settings.dailyReminderEnabled) {
      await _notificationsPlugin.cancelAll(); // Or cancel specific IDs
      return;
    }

    final timeParts = settings.dailyReminderTime.split(':');
    if (timeParts.length != 2) return;

    final hour = int.tryParse(timeParts[0]) ?? 8;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    final scheduledToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      hour,
      minute,
    );
    if (settings.quietHoursEnabled &&
        NotificationSchedulePolicy.isWithinQuietHours(
          scheduledToday,
          settings.quietHoursStart,
          settings.quietHoursEnd,
        )) {
      await _notificationsPlugin.cancel(id: 9999);
      return;
    }

    // جلب آخر حالة للمستخدم
    final context = HomeContextService().current;

    // محاولة جلب آية من الخادم بناءً على هذا السياق لتكون رسالة الغد
    String title = 'الورد اليومي للسكينة 🌿';
    String body = 'لا تنسَ قراءة وردك اليومي، وتجديد نيتك واستشعار معية الله.';

    try {
      final rec = await ApiService().getRecommendation(
        context.dominantEmotion != 'طبيعي'
            ? context.dominantEmotion
            : 'نصيحة قرآنية للطمأنينة اليومية',
      );
      if (rec.source != null && rec.source!.isNotEmpty) {
        title = '﴿ ${rec.source} ﴾';
      } else {
        title = 'رسالة اليوم 🌿';
      }
      body = rec.message;
    } catch (_) {} // Fallback to default if offline

    // We schedule it for the next occurrence of the requested time
    final next = NotificationSchedulePolicy.nextInstanceOfTime(
      DateTime.now(),
      hour,
      minute,
    );
    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'murassikh_daily',
          'التذكير اليومي',
          channelDescription: 'قناة التذكير اليومي',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(''),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF115E59),
        );

    // Cancel previous scheduled reminders
    await _notificationsPlugin.cancel(id: 9999);

    await _notificationsPlugin.zonedSchedule(
      id: 9999,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily',
    );
  }

  void _scheduleDailyRemindersIfNeeded() {
    scheduleContextualDailyReminder();
  }
}
