import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../bloc/recommendation_bloc.dart';
import '../../../../core/theme/app_colors.dart';

class MicButton extends StatefulWidget {
  final Function(String path)? onRecordComplete;
  const MicButton({super.key, this.onRecordComplete});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('صلاحية الميكروفون'),
            content: const Text('نحتاج إلى صلاحية الميكروفون لتسجيل مقطع صوتي قصير وتحليل نبرتك لتقديم الآية المناسبة لحالتك.\nلا يتم حفظ المقطع على خوادمنا.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
        
        // Let the package request the permission
        if (!await _audioRecorder.hasPermission()) {
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: filePath,
      );
      if (mounted) {
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        if (path != null && widget.onRecordComplete != null) {
          widget.onRecordComplete!(path);
        } else if (path != null) {
          context.read<RecommendationBloc>().add(AnalyzeAudioEvent(path));
        }
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(
              _isRecording ? 12.0 + (_animationController.value * 4) : 12.0,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? Colors.red : AppColors.primary,
              boxShadow: _isRecording
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: _animationController.value * 5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic_none,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
