with open("frontend/lib/features/settings/views/rate_app_screen.dart", "r") as f:
    content = f.read()

import_statement = "import '../../../services/api_service.dart';"

if "import '../../../services/api_service.dart';" not in content:
    content = content.replace("import '../../../core/theme/app_colors.dart';", f"import '../../../core/theme/app_colors.dart';\n{import_statement}")

old_method = """  Future<void> _submitRating() async {
    setState(() => _isSubmitted = true);
    // TODO: Implement rating submission to backend
    // await ApiService().submitRating(_rating, _feedback);
  }"""

new_method = """  Future<void> _submitRating() async {
    setState(() => _isSubmitted = true);
    try {
      await ApiService().submitRating(_rating, _feedback);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء إرسال التقييم. حاول مرة أخرى.')),
        );
        setState(() => _isSubmitted = false);
      }
    }
  }"""

content = content.replace(old_method, new_method)

with open("frontend/lib/features/settings/views/rate_app_screen.dart", "w") as f:
    f.write(content)
