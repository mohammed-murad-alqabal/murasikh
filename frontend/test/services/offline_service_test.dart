import 'package:flutter_test/flutter_test.dart';
import 'package:murassikh_app/services/offline_service.dart';

void main() {
  test('fallbackRecommendation returns correct default message', () {
    final offlineService = OfflineService();
    final recommendation = offlineService.fallbackRecommendation;
    expect(
      recommendation.message,
      contains('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ'),
    );
    expect(recommendation.emotion, equals('طبيعي'));
    expect(recommendation.source, contains('سورة الرعد'));
  });
}
