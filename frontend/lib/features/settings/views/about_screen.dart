import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عن مُرَسِّخ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSection(context, 'نبذة عن التطبيق', [
              _buildText(context, '''
مُرَسِّخ هو رفيقك الروحي الذكي، نظام ذكاء اصطناعي متقدم يرافقك في حياتك اليومية، يعمل على تحليل السياق والمشاعر لتقديم توجيه ديني وروحي يعتمد على القرآن الكريم والسنة النبوية.
'''),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, 'المميزات', [
              _buildFeature(
                context,
                'تحليل المشاعر',
                'فهم الحالة العاطفية من النص',
              ),
              _buildFeature(
                context,
                'قاعدة معرفة شرعية',
                'القرآن الكريم حصرياً لضمان القطعية واليقين',
              ),
              _buildFeature(context, 'البحث الدلالي', 'RAG للدقة الشرعية'),
              _buildFeature(
                context,
                'العمل بدون إنترنت',
                'Offline-First Architecture',
              ),
              _buildFeature(
                context,
                'الاستجابة المدرجة',
                'مراعاة الحالة النفسية',
              ),
              _buildFeature(
                context,
                'الخصوصية الكاملة',
                'معالجة محلية وتشفير البيانات',
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, 'معلومات الإصدار', [
              _buildInfoRow(context, 'الإصدار', '0.1.0'),
              _buildInfoRow(context, 'البناء', '1'),
              _buildInfoRow(context, 'نظام التشغيل', 'Flutter 3.16+'),
              _buildInfoRow(context, 'اللغة', 'العربية'),
            ]),

            const SizedBox(height: 24),
            _buildSection(context, 'حقوق الملكية', [
              _buildText(context, '''
© 2026 محمد مراد القبل. جميع الحقوق محفوظة.

هذا المشروع بكامل حقوقه محفوظ للمطور محمد مراد القبل.
'''),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.handshake_outlined,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'مُرَسِّخ',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'الرفيق الروحي الذكي',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        height: 1.6,
      ),
    );
  }

  Widget _buildFeature(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
