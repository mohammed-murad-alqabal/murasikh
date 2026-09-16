import 'package:flutter_test/flutter_test.dart';
import 'package:murassikh_app/features/recommendation/models/recommendation_model.dart';

void main() {
  test('preserves interaction_id from the API contract', () {
    final model = RecommendationModel.fromJson({
      'emotion': 'حزن',
      'confidence': 0.8,
      'tier': 'moderate',
      'message': 'رسالة اختبارية',
      'interaction_id': 42,
    });

    expect(model.interactionId, 42);
    expect(model.toJson()['interaction_id'], 42);
  });
}
