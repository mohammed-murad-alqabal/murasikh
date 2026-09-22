import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:murassikh_app/features/recommendation/models/recommendation_model.dart';
import 'package:murassikh_app/services/local_account_scope.dart';
import 'package:murassikh_app/services/offline_service.dart';

void main() {
  late OfflineService offlineService;
  late Directory hiveDirectory;

  RecommendationModel recommendation(String emotion) {
    return RecommendationModel(
      emotion: emotion,
      confidence: 0.8,
      tier: 'moderate',
      message: 'رسالة $emotion',
      source: 'سورة اختبارية: 1',
    );
  }

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'murassikh_hive_test_',
    );
    Hive.init(hiveDirectory.path);
    offlineService = OfflineService();
    await offlineService.init();
  });

  setUp(() async {
    await offlineService.clearLocalData();
  });

  tearDownAll(() async {
    await offlineService.clearLocalData();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('fallbackRecommendation returns correct default message', () {
    final recommendation = offlineService.fallbackRecommendation;
    expect(
      recommendation.message,
      contains('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ'),
    );
    expect(recommendation.emotion, equals('طبيعي'));
    expect(recommendation.source, contains('سورة الرعد'));
  });

  test('caches recommendations and retrieves them by emotion', () async {
    await offlineService.cacheRecommendation(
      'رسالة حزن',
      recommendation('حزن'),
    );
    await offlineService.cacheRecommendation(
      'رسالة قلق',
      recommendation('قلق'),
    );

    expect(offlineService.getCachedRecommendation('حزن')?.emotion, 'حزن');
    expect(offlineService.getCachedRecommendation('قلق')?.emotion, 'قلق');
    expect(offlineService.getCachedRecommendation('غضب'), isNull);
    expect(offlineService.getLatestCachedRecommendation()?.emotion, 'قلق');
  });

  test('keeps no more than 20 cached recommendations', () async {
    for (var index = 0; index < 21; index++) {
      await offlineService.cacheRecommendation(
        'رسالة $index',
        recommendation('حالة$index'),
      );
    }

    final exported = await offlineService.exportData();
    final cached = exported['cached_recommendations'] as List<dynamic>;
    expect(cached, hasLength(20));
    expect(offlineService.getCachedRecommendation('حالة0'), isNull);
    expect(offlineService.getCachedRecommendation('حالة20')?.emotion, 'حالة20');
  });

  test(
    'stores separate pending feedback records even when ids match',
    () async {
      await offlineService.savePendingFeedback('42', 1);
      await offlineService.savePendingFeedback('42', -1);

      final pending = offlineService.getPendingFeedbacks();
      expect(pending, hasLength(2));
      expect(pending.map((item) => item['id']), everyElement('42'));
      expect(
        pending.map((item) => item['feedback']),
        containsAll(<int>[1, -1]),
      );
    },
  );

  test('ignores malformed pending feedback and exports valid data', () async {
    final pendingBox = Hive.box<String>(
      LocalAccountScope.boxName('pending_feedback'),
    );
    await pendingBox.put('bad', '{not-json');
    await offlineService.savePendingFeedback('7', 1);

    final exported = await offlineService.exportData();
    final pending = exported['pending_feedback'] as List<dynamic>;
    expect(pending, hasLength(1));
    expect(pending.single['id'], '7');
  });

  test('clearLocalData removes cache and pending feedback', () async {
    await offlineService.cacheRecommendation('رسالة', recommendation('حزن'));
    await offlineService.savePendingFeedback('9', 1);

    await offlineService.clearLocalData();

    final exported = await offlineService.exportData();
    expect(exported['cached_recommendations'], isEmpty);
    expect(exported['pending_feedback'], isEmpty);
    expect(offlineService.getLatestCachedRecommendation(), isNull);
  });
}
