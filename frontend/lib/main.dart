import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;

import 'core/theme/app_theme.dart';
import 'core/navigation/main_shell.dart';
import 'features/recommendation/bloc/recommendation_bloc.dart';
import 'features/settings/bloc/settings_bloc.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/history_service.dart';
import 'services/offline_service.dart';
import 'services/ambient_listening_service.dart';
import 'services/settings_service.dart';
import 'services/daily_verse_service.dart';
import 'services/home_context_service.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:workmanager/workmanager.dart';

import 'core/widgets/connectivity_wrapper.dart';
import 'widgets/auto_lock_gate.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == 'update_widget') {
        
        final response = await http.post(
          Uri.parse('http://192.168.1.106:8000/api/v1/home/verse'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'dominant_emotion': null,
            'confidence': 0.0,
            'signal_source': 'widget',
            'time_of_day': null,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final verseText = data['verse'] ?? '';
          final sourceText = data['source'] ?? '';
          
          await HomeWidget.saveWidgetData<String>('verse_text', verseText);
          await HomeWidget.saveWidgetData<String>('source_text', sourceText);
          await HomeWidget.updateWidget(
            name: 'MurassikhWidgetProvider',
            iOSName: 'MurassikhWidget',
          );
        }
      }
    } catch (e) {
      debugPrint('Workmanager task failed: $e');
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    Workmanager().initialize(
      callbackDispatcher,
    );
    // Register periodic task every hour to update the widget
    Workmanager().registerPeriodicTask(
      'widget-update-task',
      'update_widget',
      frequency: const Duration(hours: 1),
    );

    await Hive.initFlutter();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    await Future.wait([
      SettingsService().init(),
      NotificationService().init(),
      HistoryService().init(),
      OfflineService().init(),
      AmbientListeningService().initialize(),
      DailyVerseService().init(),
    ]);
    // تهيئة HomeContextService بعد الخدمات الأخرى لضمان توافر البيانات
    HomeContextService();
    runApp(const MurassikhApp());
  } catch (e, stack) {
    debugPrint("Initialization error: $e\n$stack");
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'حدث خطأ في التهيئة.\n يرجى مسح بيانات التطبيق والمحاولة مرة أخرى.\n\n$e',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

class MurassikhApp extends StatelessWidget {
  const MurassikhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => RecommendationBloc(apiService: ApiService()),
        ),
        BlocProvider(create: (context) => SettingsBloc()..add(LoadSettings())),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          final settings = settingsState.userSettings;
          final Color primaryColor = Color(
            int.parse('FF${settings.accentColor}', radix: 16),
          );

          return MaterialApp(
            title: 'مُرَسِّخ',
            debugShowCheckedModeBanner: false,
            builder: (context, child) => ConnectivityWrapper(child: child!),
            themeMode: settings.themeMode == 'dark'
                ? ThemeMode.dark
                : (settings.themeMode == 'light'
                      ? ThemeMode.light
                      : ThemeMode.system),
            theme: AppTheme.lightTheme.copyWith(
              primaryColor: primaryColor,
              colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
                primary: primaryColor,
              ),
              appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
                backgroundColor: primaryColor,
              ),
              textTheme: AppTheme.lightTheme.textTheme.apply(
                fontSizeFactor: settings.fontSize / 16.0,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: primaryColor,
              colorScheme: const ColorScheme.dark().copyWith(
                primary: primaryColor,
              ),
              appBarTheme: const AppBarTheme().copyWith(
                backgroundColor: primaryColor,
              ),
              textTheme: AppTheme.lightTheme.textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
                fontSizeFactor: settings.fontSize / 16.0,
              ),
            ),

            home: const AutoLockGate(child: MainShell()),
          );
        },
      ),
    );
  }
}
