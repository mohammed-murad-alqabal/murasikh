import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../models/user_settings.dart';
import '../../../core/theme/app_colors.dart';

class FontSizeSettingsScreen extends StatelessWidget {
  const FontSizeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حجم الخط')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewCard(context, state.userSettings),
                  const SizedBox(height: 24),
                  _buildSizeSelector(context, state.userSettings),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, UserSettings settings) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معاينة الخط',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'السلام عليكم ورحمة الله وبركاته،',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: settings.fontSize.toDouble(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'هذا مثال على كيفية تأثير حجم الخط على عرض النصوص في التطبيق.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: settings.fontSize.toDouble(),
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'آية الكرسي',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: settings.fontSize.toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: settings.fontSize.toDouble() * 1.2,
                fontWeight: FontWeight.w500,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSelector(BuildContext context, UserSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر حجم الخط',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSizeOption(
                context,
                label: 'صغير',
                size: 14,
                currentValue: settings.fontSize,
                onPressed: () => context.read<SettingsBloc>().add(
                  UpdateFontSize(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSizeOption(
                context,
                label: 'متوسط',
                size: 16,
                currentValue: settings.fontSize,
                onPressed: () => context.read<SettingsBloc>().add(
                  UpdateFontSize(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSizeOption(
                context,
                label: 'كبير',
                size: 18,
                currentValue: settings.fontSize,
                onPressed: () => context.read<SettingsBloc>().add(
                  UpdateFontSize(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSizeOption(
                context,
                label: 'كبير جداً',
                size: 20,
                currentValue: settings.fontSize,
                onPressed: () => context.read<SettingsBloc>().add(
                  UpdateFontSize(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSizeOption(
    BuildContext context, {
    required String label,
    required int size,
    required int currentValue,
    required VoidCallback onPressed,
  }) {
    final isSelected = size == currentValue;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle,
              color: isSelected ? Colors.white : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
