import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/auth_screen.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsBloc>().state.userSettings;
    _nameController = TextEditingController(text: settings.name);
    _emailController = TextEditingController(text: settings.email);
    _ageController = TextEditingController(
      text: settings.age != null ? settings.age.toString() : '',
    );
    _selectedGender = settings.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('معلوماتي الشخصية'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  final form = _formKey.currentState;
                  if (form?.validate() ?? false) {
                    final updatedSettings = state.userSettings.copyWith(
                      name: _nameController.text.trim(),
                      email: _emailController.text.trim(),
                      age: _ageController.text.isNotEmpty
                          ? int.tryParse(_ageController.text.trim())
                          : null,
                      gender: _selectedGender,
                    );
                    settingsBloc.add(UpdateSettings(settings: updatedSettings));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ تم حفظ البيانات بنجاح'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            state.userSettings.name.isNotEmpty
                                ? state.userSettings.name
                                      .substring(0, 1)
                                      .toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال الاسم';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      if (!value.contains('@')) {
                        return 'الرجاء إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- حقل العمر ---
                  _buildTextField(
                    controller: _ageController,
                    label: 'العمر',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1 || n > 120) {
                        return 'الرجاء إدخال عمر صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- اختيار الجنس ---
                  Text(
                    'الجنس',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGenderOption(
                          label: 'ذكر',
                          icon: Icons.male,
                          value: 'male',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGenderOption(
                          label: 'أنثى',
                          icon: Icons.female,
                          value: 'female',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSection(context, 'معلومات الحساب', [
                    _buildInfoRow(
                      'تاريخ التسجيل',
                      _formatDate(state.userSettings.lastLogin),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection(context, 'الحساب السحابي (اختياري)', [
                    ListTile(
                      leading: const Icon(
                        Icons.cloud_sync,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'تسجيل الدخول / إنشاء حساب',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text('لمزامنة بياناتك عبر أجهزتك'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                        );
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedGender = isSelected ? null : value;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 34,
              color: isSelected ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return ListTile(
      title: Text(value),
      subtitle: Text(label),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      tileColor: AppColors.surface,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
