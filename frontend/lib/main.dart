import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    await Future.wait([
      SettingsService().init(),
      NotificationService().init(),
      HistoryService().init(),
      OfflineService().init(),
      AmbientListeningService().initialize(),
    ]);
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
          final Color primaryColor = Color(int.parse('FF${settings.accentColor ?? '115E59'}', radix: 16));

          return MaterialApp(
            title: 'مُرَسِّخ',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode == 'dark' 
                ? ThemeMode.dark 
                : (settings.themeMode == 'light' ? ThemeMode.light : ThemeMode.system),
            theme: AppTheme.lightTheme.copyWith(
              primaryColor: primaryColor,
              colorScheme: AppTheme.lightTheme.colorScheme.copyWith(primary: primaryColor),
              appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(backgroundColor: primaryColor),
              textTheme: AppTheme.lightTheme.textTheme.apply(
                fontSizeFactor: settings.fontSize / 16.0,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: primaryColor,
              colorScheme: const ColorScheme.dark().copyWith(primary: primaryColor),
              appBarTheme: const AppBarTheme().copyWith(backgroundColor: primaryColor),
              textTheme: AppTheme.lightTheme.textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
                fontSizeFactor: settings.fontSize / 16.0,
              ),
            ),
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              );
            },
            home: const MainShell(),
          );
        },
      ),
    );
  }
}
