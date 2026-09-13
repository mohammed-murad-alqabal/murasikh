import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../../../core/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = state.userSettings;
          return ListView(
            children: [
              _buildSection(context, 'الإشعارات العامة', [
                _buildToggleTile(
                  context: context,
                  title: 'تفعيل الإشعارات',
                  subtitle: 'استلام الإشعارات من التطبيق',
                  value: settings.notificationsEnabled,
                  onChanged: (value) => settingsBloc.add(
                    UpdateNotificationsSettings(notificationsEnabled: value),
                  ),
                ),
                if (settings.notificationsEnabled) ...[
                  _buildToggleTile(
                    context: context,
                    title: 'صوت الإشعارات',
                    subtitle: 'تشغيل صوت عند وصول إشعار',
                    value: settings.notificationSound,
                    onChanged: (value) => settingsBloc.add(
                      UpdateNotificationsSettings(notificationSound: value),
                    ),
                  ),
                  _buildToggleTile(
                    context: context,
                    title: 'اهتزاز الإشعارات',
                    subtitle: 'اهتزاز الجهاز عند وصول إشعار',
                    value: settings.notificationVibrate,
                    onChanged: (value) => settingsBloc.add(
                      UpdateNotificationsSettings(notificationVibrate: value),
                    ),
                  ),
                ],
              ]),
              if (settings.notificationsEnabled) ...[
                _buildSection(context, 'التنبيهات الروحية', [
                  _buildToggleTile(
                    context: context,
                    title: 'التنبيهات الروحية التلقائية',
                    subtitle: 'استقبال توجيهات روحية عند استشعار الانفعال',
                    value: settings.spiritualAlertsEnabled,
                    onChanged: (value) => settingsBloc.add(
                      UpdateNotificationsSettings(
                        spiritualAlertsEnabled: value,
                      ),
                    ),
                  ),
                ]),
                _buildSection(context, 'أوقات عدم الإزعاج', [
                  _buildToggleTile(
                    context: context,
                    title: 'تفعيل أوقات عدم الإزعاج',
                    subtitle: 'منع الإشعارات خلال فترة محددة',
                    value: settings.quietHoursEnabled,
                    onChanged: (value) => settingsBloc.add(
                      UpdateNotificationsSettings(quietHoursEnabled: value),
                    ),
                  ),
                  if (settings.quietHoursEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'من',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  TextButton(
                                    onPressed: () => _showTimePicker(
                                      context: context,
                                      currentTime: settings.quietHoursStart,
                                      onTimeSelected: (time) =>
                                          settingsBloc.add(
                                            UpdateNotificationsSettings(
                                              quietHoursStart: time,
                                            ),
                                          ),
                                    ),
                                    child: Text(
                                      settings.quietHoursStart,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'إلى',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  TextButton(
                                    onPressed: () => _showTimePicker(
                                      context: context,
                                      currentTime: settings.quietHoursEnd,
                                      onTimeSelected: (time) =>
                                          settingsBloc.add(
                                            UpdateNotificationsSettings(
                                              quietHoursEnd: time,
                                            ),
                                          ),
                                    ),
                                    child: Text(
                                      settings.quietHoursEnd,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ]),
                _buildSection(context, 'التذكيرات اليومية', [
                  _buildToggleTile(
                    context: context,
                    title: 'التذكير اليومي',
                    subtitle: 'استلام تذكير يومي في وقت محدد',
                    value: settings.dailyReminderEnabled,
                    onChanged: (value) => settingsBloc.add(
                      UpdateNotificationsSettings(dailyReminderEnabled: value),
                    ),
                  ),
                  if (settings.dailyReminderEnabled)
                    _buildSettingsTile(
                      context: context,
                      title: 'وقت التذكير',
                      subtitle: settings.dailyReminderTime,
                      trailing: TextButton(
                        onPressed: () => _showTimePicker(
                          context: context,
                          currentTime: settings.dailyReminderTime,
                          onTimeSelected: (time) => settingsBloc.add(
                            UpdateNotificationsSettings(
                              dailyReminderTime: time,
                            ),
                          ),
                        ),
                        child: Text(
                          settings.dailyReminderTime,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        value ? Icons.notifications_active : Icons.notifications_off,
        color: AppColors.primary,
        size: 22,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(Icons.access_time, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing,
    );
  }

  void _showTimePicker({
    required BuildContext context,
    required String currentTime,
    required Function(String) onTimeSelected,
  }) {
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    ).then((time) {
      if (time != null) {
        final formattedTime =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        onTimeSelected(formattedTime);
      }
    });
  }
}

// Event for updating notification settings
class UpdateNotificationsSettings extends SettingsEvent {
  final bool? notificationsEnabled;
  final bool? notificationSound;
  final bool? notificationVibrate;
  final bool? quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final bool? dailyReminderEnabled;
  final String? dailyReminderTime;
  final bool? spiritualAlertsEnabled;

  UpdateNotificationsSettings({
    this.notificationsEnabled,
    this.notificationSound,
    this.notificationVibrate,
    this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.dailyReminderEnabled,
    this.dailyReminderTime,
    this.spiritualAlertsEnabled,
  });
}
