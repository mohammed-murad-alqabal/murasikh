import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/privacy_data_service.dart';
import 'screens/personal_info_screen.dart';
import 'views/privacy_screen.dart';
import 'views/notifications_screen.dart';
import 'views/theme_screen.dart';
import 'views/about_screen.dart';
import 'views/rate_app_screen.dart';
import 'views/font_size_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          _buildSection(context, 'الحساب والملف الشخصي', [
            _buildTile(
              context,
              icon: Icons.person_outline,
              title: 'معلوماتي الشخصية',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalInfoScreen(),
                  ),
                );
              },
            ),
            _buildTile(
              context,
              icon: Icons.language,
              title: 'اللغة',
              subtitle: 'العربية',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سيتم دعم اللغات الإضافية قريباً'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ]),
          _buildSection(context, 'التطبيق', [
            _buildTile(
              context,
              icon: Icons.notifications_outlined,
              title: 'الإشعارات',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            _buildTile(
              context,
              icon: Icons.color_lens_outlined,
              title: 'المظهر',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ThemeScreen()),
                );
              },
            ),
            _buildTile(
              context,
              icon: Icons.text_fields,
              title: 'حجم الخط',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FontSizeSettingsScreen(),
                  ),
                );
              },
            ),
          ]),
          _buildSection(context, 'الخصوصية والأمان', [
            _buildTile(
              context,
              icon: Icons.lock_outline,
              title: 'الخصوصية',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyScreen(),
                  ),
                );
              },
            ),
            _buildTile(
              context,
              icon: Icons.delete_outline,
              title: 'مسح بيانات السجل',
              isDestructive: true,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('مسح بيانات السجل'),
                    content: const Text(
                      'هل أنت متأكد من مسح سجل التوجيه والكاش والإشعارات نهائياً؟',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('مسح'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final result = await PrivacyDataService().clearAllUserData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !result.localCleared
                              ? 'تعذر مسح بعض البيانات المحلية'
                              : result.remoteDeletionConfirmed
                                  ? 'تم مسح جميع البيانات محلياً ومن الخادم'
                                  : 'تم مسح البيانات المحلية، ولم يتأكد الحذف من الخادم',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ]),
          _buildSection(context, 'حول التطبيق', [
            _buildTile(
              context,
              icon: Icons.info_outline,
              title: 'عن مُرَسِّخ',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
            _buildTile(
              context,
              icon: Icons.star_outline,
              title: 'قيّم التطبيق',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RateAppScreen(),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> tiles) {
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
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Function()? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.primary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right, // صحيح في RTL: السهم يشير لليمين (الأمام)
        color: AppColors.textSecondary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
