import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../../../core/theme/app_colors.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    return Scaffold(
      appBar: AppBar(title: const Text('المظهر')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final settings = state.userSettings;
          return ListView(
            children: [
              _buildSection(context, 'الوضع', [
                _buildThemeModeOption(
                  context: context,
                  title: 'فاتح',
                  subtitle: 'استخدام الوضع الفاتح دائماً',
                  icon: Icons.light_mode,
                  value: 'light',
                  currentValue: settings.themeMode,
                  onTap: () =>
                      settingsBloc.add(UpdateThemeSettings(themeMode: 'light')),
                ),
                _buildThemeModeOption(
                  context: context,
                  title: 'داكن',
                  subtitle: 'استخدام الوضع الداكن دائماً',
                  icon: Icons.dark_mode,
                  value: 'dark',
                  currentValue: settings.themeMode,
                  onTap: () =>
                      settingsBloc.add(UpdateThemeSettings(themeMode: 'dark')),
                ),
                _buildThemeModeOption(
                  context: context,
                  title: 'تلقائي (حسب النظام)',
                  subtitle: 'اتباع إعدادات النظام تلقائياً',
                  icon: Icons.settings_suggest,
                  value: 'system',
                  currentValue: settings.themeMode,
                  onTap: () => settingsBloc.add(
                    UpdateThemeSettings(themeMode: 'system'),
                  ),
                ),
              ]),
              _buildSection(context, 'اللون الرئيسي', [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختر لون التمييز للتطبيق',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildColorOption(
                            context: context,
                            colorHex: '115E59',
                            colorName: 'زمردي',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: '1565C0',
                            colorName: 'أزرق',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: '7B1FA2',
                            colorName: 'بنفسجي',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: 'C62828',
                            colorName: 'أحمر',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: 'F57C00',
                            colorName: 'برتقالي',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: '2E7D32',
                            colorName: 'أخضر',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: '00838F',
                            colorName: 'سماوي',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                          _buildColorOption(
                            context: context,
                            colorHex: '5D4037',
                            colorName: 'بني',
                            settingsBloc: settingsBloc,
                            currentColor: settings.accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
              _buildPreviewSection(context, settings.accentColor),
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

  Widget _buildThemeModeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String currentValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == currentValue;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Widget _buildColorOption({
    required BuildContext context,
    required String colorHex,
    required String colorName,
    required SettingsBloc settingsBloc,
    required String currentColor,
  }) {
    final isSelected = colorHex == currentColor;
    final color = Color(int.parse('FF$colorHex', radix: 16));

    return InkWell(
      onTap: () => settingsBloc.add(UpdateThemeSettings(accentColor: colorHex)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : AppColors.textSecondary.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              colorName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context, String accentColor) {
    final color = Color(int.parse('FF$accentColor', radix: 16));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'معاينة',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'مُرَسِّخ',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرفيق الروحي الذكي',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('زر رئيسي'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                        ),
                        child: const Text('زر ثانوي'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
