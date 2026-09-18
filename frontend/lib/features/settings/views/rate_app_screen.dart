import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart';

class RateAppScreen extends StatefulWidget {
  const RateAppScreen({super.key});

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
  int _rating = 0;
  String? _feedback;
  bool _isSubmitted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قيّم التطبيق')),
      body: _isSubmitted ? _buildSuccessView() : _buildRatingView(),
    );
  }

  Widget _buildRatingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildRatingSection(context),
          const SizedBox(height: 24),
          _buildFeedbackSection(context),
          const SizedBox(height: 24),
          _buildButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.star_rounded, size: 64, color: AppColors.secondary),
        const SizedBox(height: 16),
        Text(
          'نُقدّر تقييمك!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ساعدنا في تحسين مُرَسِّخ من خلال مشاركتك تجربتك',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'كم هو تقييمك للتطبيق؟',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRatingOption(context, 1),
              _buildRatingOption(context, 2),
              _buildRatingOption(context, 3),
              _buildRatingOption(context, 4),
              _buildRatingOption(context, 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingOption(BuildContext context, int rating) {
    final isSelected = _rating == rating;
    final icon = rating <= 2
        ? Icons.sentiment_very_dissatisfied
        : rating == 3
        ? Icons.sentiment_neutral
        : Icons.sentiment_very_satisfied;

    return InkWell(
      onTap: () => setState(() => _rating = rating),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            rating.toString(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'هل لديك ملاحظات أو اقتراحات؟',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'اكتب ملاحظاتك هنا...',
            hintText: 'ساعدنا في تحسين التطبيق...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) => _feedback = value,
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _rating > 0 ? _submitRating : null,
            icon: const Icon(Icons.send),
            label: const Text('إرسال التقييم'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: AppColors.textSecondary.withValues(
                alpha: 0.3,
              ),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _rating > 0 ? _rateInStore : null,
          icon: const Icon(Icons.star),
          label: const Text('أو قِّم في المتجر مباشرة'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 50,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'شكراً لتقييمك!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _feedback != null && _feedback!.isNotEmpty
                  ? 'لقد قرأنا ملاحظاتك وسنأخذها بعين الاعتبار.'
                  : 'يسعدنا أنك استمتعت باستخدام مُرَسِّخ!',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitted = true);
    try {
      await ApiService().submitRating(_rating, _feedback);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء إرسال التقييم. حاول مرة أخرى.'),
          ),
        );
        setState(() => _isSubmitted = false);
      }
    }
  }

  Future<void> _rateInStore() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.murassikh.app';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح المتجر')));
      }
    }
  }
}
