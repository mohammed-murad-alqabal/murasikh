import re

with open("frontend/lib/features/recommendation/views/recommendation_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# We need to add state for feedback
state_vars = """
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasFeedback = false;
"""
content = re.sub(r'  final TextEditingController _controller = TextEditingController\(\);\n  final FocusNode _focusNode = FocusNode\(\);', state_vars, content)

# Reset feedback on submit
submit_func = """  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _hasFeedback = false;
    });
    _focusNode.unfocus();
"""
content = content.replace("""  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    _focusNode.unfocus();""", submit_func)

# Replace the OutlinedButton (copy button) with a Row containing Feedback and Copy
feedback_row = """
                  // أزرار التفاعل (نسخ + تقييم)
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: '${rec.message}\\n${rec.source ?? ''}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ الرسالة 📋'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ الرسالة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      
                      // Feedback
                      if (!_hasFeedback)
                        Row(
                          children: [
                            Text('هل ساعدتك؟', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            IconButton(
                              icon: Icon(Icons.thumb_up_alt_outlined, size: 20, color: Colors.green.shade600),
                              onPressed: () {
                                setState(() { _hasFeedback = true; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('شكراً لتقييمك الإيجابي! سيتعلم النظام منه.'), duration: Duration(seconds: 2)),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.thumb_down_alt_outlined, size: 20, color: Colors.red.shade600),
                              onPressed: () {
                                setState(() { _hasFeedback = true; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('شكراً لملاحظتك. سنقوم بتحسين النتائج مستقبلاً.'), duration: Duration(seconds: 2)),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        )
                      else
                        Text('شكراً لتقييمك!', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
"""

old_button = """                  // زر نسخ الآية
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: '${rec.message}\\n${rec.source ?? ''}',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم نسخ الرسالة 📋'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('نسخ الرسالة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),"""
                  
content = content.replace(old_button, feedback_row)

with open("frontend/lib/features/recommendation/views/recommendation_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
