class RecommendationModel {
  final String emotion;
  final double confidence;
  final String tier;
  final String? contentType;
  final String message;
  final String? delayedMessage;
  final String? source;
  final String? tafsir;
  final String? action;

  RecommendationModel({
    required this.emotion,
    required this.confidence,
    required this.tier,
    this.contentType,
    required this.message,
    this.delayedMessage,
    this.source,
    this.tafsir,
    this.action,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      emotion: json['emotion'] ?? 'طبيعي',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      tier: json['tier'] ?? 'full',
      contentType: json['content_type'],
      message: json['text'] ?? json['message'] ?? '',
      delayedMessage: json['delayed_message'],
      source: json['source'],
      tafsir: json['tafsir'],
      action: json['action'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion,
      'confidence': confidence,
      'tier': tier,
      'contentType': contentType,
      'message': message,
      'delayed_message': delayedMessage,
      'source': source,
      'tafsir': tafsir,
      'action': action,
    };
  }
}
