import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../features/recommendation/models/recommendation_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

class FaceEmotionService extends ChangeNotifier with WidgetsBindingObserver {
  static final FaceEmotionService _instance = FaceEmotionService._internal();
  factory FaceEmotionService() => _instance;
  FaceEmotionService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  
  bool _isAnalyzing = false;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  
  String _detectedEmotion = 'طبيعي';
  RecommendationModel? _recommendation;
  DateTime _lastAnalysisTime = DateTime.now();

  CameraController? get cameraController => _cameraController;
  bool get isAnalyzing => _isAnalyzing;
  bool get isCameraReady => _isCameraReady;
  String get detectedEmotion => _detectedEmotion;
  RecommendationModel? get recommendation => _recommendation;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_isAnalyzing) {
        _cameraController!.stopImageStream();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isAnalyzing) {
        _cameraController!.startImageStream(_processCameraImage);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> initialize() async {
    if (_isCameraReady) return;

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    _isCameraReady = true;
    notifyListeners();
  }

  void toggleAnalysis() {
    if (!_isCameraReady || _cameraController == null) return;
    
    _isAnalyzing = !_isAnalyzing;
    notifyListeners();

    if (_isAnalyzing) {
      _cameraController!.startImageStream(_processCameraImage);
    } else {
      _cameraController!.stopImageStream();
      _detectedEmotion = 'طبيعي';
      _recommendation = null;
      notifyListeners();
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isAnalyzing || _isProcessingFrame) return;

    // معالجة صورة واحدة كل 3 ثوانٍ فقط للحفاظ على البطارية وتجنب الضغط
    if (DateTime.now().difference(_lastAnalysisTime).inSeconds < 3) return;

    _isProcessingFrame = true;
    _lastAnalysisTime = DateTime.now();

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final InputImageRotation imageRotation = InputImageRotation.rotation270deg; // Front camera on portrait
      final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        _detectedEmotion = 'لم يتم اكتشاف وجه';
        notifyListeners();
        _isProcessingFrame = false;
        return;
      }

      final emotion = _mapFaceToEmotion(faces.first);
      if (_detectedEmotion != emotion) {
        _detectedEmotion = emotion;
        notifyListeners();

        if (emotion != 'طبيعي' && emotion != 'لم يتم اكتشاف وجه' && emotion != 'بشاشة') {
          final contextQuery = _emotionToContext(emotion);
          final rec = await ApiService().getRecommendation(contextQuery);
          _recommendation = rec;
          notifyListeners();
          
          await NotificationService().showSpiritualAlert(
            emotion: emotion,
            tier: rec.tier,
            message: rec.message,
            source: rec.source,
            tafsir: rec.tafsir,
          );
        }
      }
    } catch (e) {
      debugPrint('Error processing image stream: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  String _mapFaceToEmotion(Face face) {
    final smileProb = face.smilingProbability ?? 0.0;
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;
    final avgEye = (leftEye + rightEye) / 2;

    if (smileProb > 0.75) return 'فرح';
    if (smileProb > 0.45) return 'بشاشة';
    if (avgEye < 0.25) return 'إجهاد أو حزن';
    if (avgEye < 0.5 && smileProb < 0.2) return 'قلق أو توتر';
    return 'طبيعي';
  }

  String _emotionToContext(String emotion) {
    const map = {
      'فرح': 'أشعر بالفرح والسعادة وابتسامتي واسعة',
      'بشاشة': 'أشعر بالراحة والبشاشة الخفيفة',
      'إجهاد أو حزن': 'أنا حزين ومجهد وتبدو ملامحي متعبة',
      'قلق أو توتر': 'أشعر بالقلق والتوتر المستمر',
    };
    return map[emotion] ?? 'حالتي طبيعية';
  }
}
