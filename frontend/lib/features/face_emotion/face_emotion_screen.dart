import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/face_emotion_service.dart';
import '../../core/theme/app_colors.dart';

class FaceEmotionScreen extends StatefulWidget {
  const FaceEmotionScreen({super.key});

  @override
  State<FaceEmotionScreen> createState() => _FaceEmotionScreenState();
}

class _FaceEmotionScreenState extends State<FaceEmotionScreen> {
  final FaceEmotionService _faceService = FaceEmotionService();

  @override
  void initState() {
    super.initState();
    // Initialize if not ready
    if (!_faceService.isCameraReady) {
      _faceService.initialize();
    }
  }

  String _emotionToEmoji(String emotion) {
    const map = {
      'فرح': '😊', 'بشاشة': '🙂',
      'إجهاد أو حزن': '😔', 'قلق أو توتر': '😟',
      'لم يتم اكتشاف وجه': '🔍',
    };
    return map[emotion] ?? '😐';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحليل تعابير الوجه'), centerTitle: true),
      body: AnimatedBuilder(
        animation: _faceService,
        builder: (context, _) {
          final isReady = _faceService.isCameraReady;
          final isAnalyzing = _faceService.isAnalyzing;
          final emotion = _faceService.detectedEmotion;
          final emoji = _emotionToEmoji(emotion);
          final rec = _faceService.recommendation;

          return SingleChildScrollView(
            child: Column(
              children: [
                if (isReady && _faceService.cameraController != null)
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                      child: CameraPreview(_faceService.cameraController!),
                    ),
                  )
                else
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text('جاري تهيئة الكاميرا...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // حالة التشغيل وإيقاف التشغيل
                      Card(
                        color: isAnalyzing ? Colors.teal.shade50 : Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: SwitchListTile(
                          title: Text(
                            isAnalyzing ? 'التحليل المستمر مُفعّل' : 'التحليل المستمر مُتوقف',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAnalyzing ? Colors.teal.shade700 : Colors.red.shade700,
                            ),
                          ),
                          subtitle: Text(
                            isAnalyzing 
                              ? 'يقوم التطبيق الآن بتحليل وجهك في الخلفية حتى لو انتقلت لشاشة أخرى.'
                              : 'قم بتفعيل التحليل لتبدأ كاميرا الرفيق الروحي بالعمل.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isAnalyzing,
                          activeThumbColor: Colors.teal,
                          onChanged: isReady ? (_) => _faceService.toggleAnalysis() : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // عرض الشعور
                      if (isAnalyzing && emotion.isNotEmpty)
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(children: [
                              Text(emoji, style: const TextStyle(fontSize: 64)),
                              const SizedBox(height: 12),
                              Text(
                                'الشعور المكتشف: $emotion',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ]),
                          ),
                        ),

                      // عرض رسالة الرفيق إن وُجدت
                      if (isAnalyzing && rec != null && emotion != 'طبيعي' && emotion != 'بشاشة') ...[
                        const SizedBox(height: 20),
                        Card(
                          elevation: 4,
                          color: AppColors.primary.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_rounded, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'رسالة الرفيق الروحي',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                                Text(
                                  rec.message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.6),
                                ),
                                if (rec.source != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      rec.source!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
