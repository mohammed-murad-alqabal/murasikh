import 'package:flutter_test/flutter_test.dart';

import 'package:murassikh_app/services/history_service.dart';

void main() {
  test('DelayedResponseItem parses the delivered payload', () {
    final item = DelayedResponseItem.fromMap({
      'id': 7,
      'interaction_id': 42,
      'emotion': 'يأس',
      'confidence': 0.95,
      'tier': 'full',
      'message': 'رسالة مؤجلة',
      'source': 'سورة الاختبار: 1',
      'tafsir': 'تفسير اختباري',
    });

    expect(item.id, 7);
    expect(item.interactionId, 42);
    expect(item.recommendation.message, 'رسالة مؤجلة');
    expect(item.recommendation.emotion, 'يأس');
    expect(item.recommendation.interactionId, 42);
  });
}
