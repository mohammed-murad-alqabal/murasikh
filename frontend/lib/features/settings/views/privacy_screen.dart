import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../bloc/settings_bloc.dart';
import '../models/user_settings.dart';
import '../../../core/theme/app_colors.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  Future<void> _exportData() async {
    try {
      if (!Hive.isBoxOpen('murassikh_chat_box')) {
        await Hive.openBox('murassikh_chat_box');
      }
      final box = Hive.box('murassikh_chat_box');
      final data = box.values.toList();
      final String jsonStr = jsonEncode(data);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/murassikh_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تصدير البيانات بنجاح إلى:\n${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية والأمان')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              _buildSection(context, 'الخصوصية', [
                _buildToggleTile(
                  context: context,
                  title: 'إخفاء المحتوى في قفل الشاشة',
                  subtitle: 'إخفاء تفاصيل الرسائل في شاشة القفل',
                  value: state.userSettings.hideContentInLockScreen,
                  onChanged: (value) => settingsBloc.add(
                    UpdatePrivacySettings(hideContentInLockScreen: value),
                  ),
                ),
                _buildToggleTile(
                  context: context,
                  title: 'التحقق من الهوية (البصمة/الوجه)',
                  subtitle: 'المطالبة بالتحقق عند فتح التطبيق',
                  value: state.userSettings.enableBiometricAuth,
                  onChanged: (value) => settingsBloc.add(
                    UpdatePrivacySettings(enableBiometricAuth: value),
                  ),
                ),
              ]),
              _buildSection(context, 'الأمان', [
                _buildToggleTile(
                  context: context,
                  title: 'قفل تلقائي',
                  subtitle: 'قفل التطبيق تلقائياً بعد فترة من السكون',
                  value: state.userSettings.autoLockEnabled,
                  onChanged: (value) => settingsBloc.add(
                    UpdatePrivacySettings(autoLockEnabled: value),
                  ),
                ),
                if (state.userSettings.autoLockEnabled)
                  _buildSettingsTile(
                    context: context,
                    title: 'وقت القفل التلقائي',
                    subtitle:
                        '${state.userSettings.autoLockTimeoutMinutes} دقائق',
                    trailing: Text(
                      '${state.userSettings.autoLockTimeoutMinutes}د',
                    ),
                    onTap: () => _showAutoLockDialog(
                      context,
                      state.userSettings,
                      settingsBloc,
                    ),
                  ),
                _buildToggleTile(
                  context: context,
                  title: 'مسح السجل عند الخروج',
                  subtitle: 'حذف سجل التوجيه تلقائياً عند إغلاق التطبيق',
                  value: state.userSettings.clearHistoryOnExit,
                  onChanged: (value) => settingsBloc.add(
                    UpdatePrivacySettings(clearHistoryOnExit: value),
                  ),
                ),
              ]),
              _buildSection(context, 'المشاركة والتحليل', [
                _buildToggleTile(
                  context: context,
                  title: 'مشاركة التحليلات',
                  subtitle:
                      'مساعدة تطوير مُرَسِّخ عبر مشاركة بيانات استخدام مجهولة',
                  value: state.userSettings.shareAnalytics,
                  onChanged: (value) => settingsBloc.add(
                    UpdatePrivacySettings(shareAnalytics: value),
                  ),
                ),
              ]),
              _buildSection(context, 'إدارة البيانات', [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppColors.primary, size: 22),
                  title: const Text('تصدير بياناتي', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('حفظ نسخة من محادثاتك وسجلاتك بصيغة JSON', style: Theme.of(context).textTheme.bodySmall),
                  onTap: _exportData,
                ),
                _buildWarningTile(
                  context: context,
                  title: 'مسح السجل',
                  subtitle: 'حذف جميع سجلات التوجيه والتفاعلات (لا يمكن الاسترجاع)',
                  onPressed: () =>
                      _showClearHistoryDialog(context, settingsBloc),
                ),
              ]),
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
        value ? Icons.lock : Icons.lock_open,
        color: AppColors.primary,
        size: 22,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(Icons.settings, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildWarningTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return ListTile(
      leading: Icon(
        Icons.warning_amber_outlined,
        color: AppColors.error,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_left,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onTap: onPressed,
    );
  }

  void _showAutoLockDialog(
    BuildContext context,
    UserSettings settings,
    SettingsBloc settingsBloc,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('وقت القفل التلقائي'),
        content: StatefulBuilder(
          builder: (dialogContext, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('30 ثانية'),
                trailing: settings.autoLockTimeoutMinutes == 0.5
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  settingsBloc.add(
                    UpdatePrivacySettings(autoLockTimeoutMinutes: 0.5),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('دقيقة واحدة'),
                trailing: settings.autoLockTimeoutMinutes == 1
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  settingsBloc.add(
                    UpdatePrivacySettings(autoLockTimeoutMinutes: 1),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('3 دقائق'),
                trailing: settings.autoLockTimeoutMinutes == 3
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  settingsBloc.add(
                    UpdatePrivacySettings(autoLockTimeoutMinutes: 3),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('5 دقائق'),
                trailing: settings.autoLockTimeoutMinutes == 5
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  settingsBloc.add(
                    UpdatePrivacySettings(autoLockTimeoutMinutes: 5),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('10 دقائق'),
                trailing: settings.autoLockTimeoutMinutes == 10
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  settingsBloc.add(
                    UpdatePrivacySettings(autoLockTimeoutMinutes: 10),
                  );
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(
    BuildContext context,
    SettingsBloc settingsBloc,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مسح السجل'),
        content: const Text(
          'هل أنت متأكد من مسح جميع سجلات التوجيه والتفاعلات؟ هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              settingsBloc.add(ClearHistory());
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم مسح السجل')));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }
}
