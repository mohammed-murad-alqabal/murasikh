/// نموذج بيانات الآية الديناميكية المُرشَّحة
class VerseCard {
  final String verse;
  final String source;
  final String? tafsir;
  final String emotionContext;

  /// المصدر الذي استُخدم لتحديد الآية:
  /// «face» | «audio» | «history» | «time»
  final String signalUsed;

  /// هل جاءت من الكاش المحلي؟
  final bool cached;

  final DateTime fetchedAt;

  const VerseCard({
    required this.verse,
    required this.source,
    this.tafsir,
    required this.emotionContext,
    required this.signalUsed,
    this.cached = false,
    required this.fetchedAt,
  });

  /// تسمية مرجعية قابلة للعرض لمصدر الإشارة
  String get signalLabel {
    switch (signalUsed) {
      case 'face':
        return 'بناءً على تعابير وجهك';
      case 'audio':
        return 'بناءً على ما استشعره النظام';
      case 'history':
        return 'بناءً على تفاعلاتك الأخيرة';
      case 'time':
        return _timeLabel();
      default:
        return 'مرشّحة لك';
    }
  }

  String _timeLabel() {
    switch (emotionContext) {
      case 'فجر':
        return 'آية الفجر 🌙';
      case 'صباح':
        return 'آية الصباح ☀️';
      case 'ظهر':
        return 'آية الظهر 🌤️';
      case 'عصر':
        return 'آية العصر 🌅';
      case 'مساء':
        return 'آية المساء 🌆';
      case 'ليل':
        return 'آية الليل 🌃';
      default:
        return 'آية اليوم';
    }
  }

  factory VerseCard.fromJson(Map<String, dynamic> json, {bool cached = false}) {
    return VerseCard(
      verse: json['verse'] as String? ?? '',
      source: json['source'] as String? ?? '',
      tafsir: json['tafsir'] as String?,
      emotionContext: json['emotion_context'] as String? ?? 'طبيعي',
      signalUsed: json['signal_used'] as String? ?? 'time',
      cached: cached,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'verse': verse,
        'source': source,
        'tafsir': tafsir,
        'emotion_context': emotionContext,
        'signal_used': signalUsed,
        'cached': cached,
        'fetched_at': fetchedAt.toIso8601String(),
      };

  /// نسخة احتياطية تُعرض عند انعدام الإنترنت وفراغ الكاش
  static VerseCard get fallback => VerseCard(
        verse: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
        source: 'سورة الرعد: ٢٨',
        tafsir:
            'ذكر الله سبحانه هو مفتاح الطمأنينة والراحة النفسية في كل وقت وحين.',
        emotionContext: 'طبيعي',
        signalUsed: 'time',
        cached: true,
        fetchedAt: DateTime.now(),
      );
}
